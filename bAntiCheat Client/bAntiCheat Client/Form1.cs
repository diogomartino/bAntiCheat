using MaterialSkin;
using MaterialSkin.Controls;
using System;
using System.Diagnostics;
using System.IO;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Windows.Forms;

namespace bAntiCheat_Client
{
    public partial class Form1 : MaterialForm
    {
        private TcpClient socketConnection;
        private Thread clientReceiveThread;
        private Player p = new Player();
        private Anticheat AC;
        private static string dataPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "bAntiCheat\\");

        public Form1()
        {
            InitializeComponent();

            var materialSkinManager = MaterialSkinManager.Instance;
            materialSkinManager.AddFormToManage(this);
            materialSkinManager.Theme = MaterialSkinManager.Themes.LIGHT;
            materialSkinManager.ColorScheme = new ColorScheme(Primary.DeepOrange800, Primary.DeepOrange900, Primary.BlueGrey500, Accent.LightBlue200, TextShade.WHITE);

            if(!Directory.Exists(dataPath))
            {
                if(string.IsNullOrEmpty(Anticheat.GetGTAPath())) {
                    MessageBox.Show("Can't find the GTA installation directory. Please reinstall SAMP.", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    Environment.Exit(-1);
                }

                Directory.CreateDirectory(dataPath);
                File.WriteAllLines(Path.Combine(dataPath, "data.txt"), new string[] { "127.0.0.1", "9014"});
            }

            string[] lines = File.ReadAllLines(Path.Combine(dataPath, "data.txt"));
            textBoxIp.Text = lines[0].Trim();
            textBoxPort.Text = lines[1].Trim();
        }

        private void Form1_Load(object sender, EventArgs e)
        {

        }

        private void materialRaisedButton1_Click(object sender, EventArgs e)
        {
            try
            {
                File.WriteAllLines(Path.Combine(dataPath, "data.txt"), new string[] { textBoxIp.Text, textBoxPort.Text });
            }
            catch { }

            UpdateStatusLabel("Connecting...");

            clientReceiveThread = new Thread(new ThreadStart(ListenForData));
            clientReceiveThread.Start();

            ToggleConnectButton(false);
        }

        private void UpdateStatusLabel(string text)
        {
            MethodInvoker action = delegate { statusLabel.Text = text; statusLabel.Visible = true; };
            statusLabel.BeginInvoke(action);
        }

        private void ToggleConnectButton(bool state)
        {
            MethodInvoker action = delegate { materialRaisedButton1.Enabled = state; };
            materialRaisedButton1.BeginInvoke(action);
        }

        private void UpdateUserInfoLabels(string name)
        {
            MethodInvoker action = delegate { labelPlayerName.Text = name; labelPlayerName.Visible = true; };
            labelPlayerName.BeginInvoke(action);

            action = delegate { label1.Visible = true; };
            label1.BeginInvoke(action);
        }

        private void UpdateJoinCodeLabel(string text)
        {
            MethodInvoker action = delegate { joinCodeLabel.Text = text; joinCodeLabel.Visible = true; };
            joinCodeLabel.BeginInvoke(action);
        }

        public static void WriteLog(string text)
        {
            string logPath = Path.Combine(dataPath, "log.txt");
            File.AppendAllText(logPath, string.Format("\n---------------------[{0}] : {1}", DateTime.Now.ToString("yyyy-MM-dd hh:mm:ss"), text));
        }

        private void SendMessage(string clientMessage)
        {
            if (socketConnection != null)
            {
                clientMessage = clientMessage.Trim();

                try
                {
                    NetworkStream stream = socketConnection.GetStream();
                    if (stream.CanWrite)
                    {
                        byte[] clientMessageAsByteArray = Encoding.ASCII.GetBytes(clientMessage);

                        stream.Write(clientMessageAsByteArray, 0, clientMessageAsByteArray.Length);
                    }
                }
                catch (SocketException socketException)
                {
                    UpdateStatusLabel("An error occurred. Check the logs.");
                    WriteLog(socketException.ToString());
                }
            }
        }

        private void ListenForData()
        {
            try
            {
                socketConnection = new TcpClient(textBoxIp.Text, int.Parse(textBoxPort.Text));

                try
                {
                    p.generateNewJoinCode();

                    MethodInvoker action = delegate { Clipboard.SetText(p.joinCode.ToString()); };
                    labelPlayerName.BeginInvoke(action);

                    UpdateJoinCodeLabel(p.joinCode.ToString());

                    string welcomeMsg = string.Format("CONNECTED:{0}|{1}|{2}", p.uniqueID, p.securityID, p.joinCode);
                    SendMessage(welcomeMsg);
                }
                catch (Exception ex)
                {
                    UpdateStatusLabel("An error occurred. Check the logs.");
                    WriteLog(ex.ToString());
                    ToggleConnectButton(true);
                }

                byte[] bytes = new byte[1024];

                while (socketConnection.Connected)
                {	
                    try
                    {
                        using (NetworkStream stream = socketConnection.GetStream())
                        {
                            int length;
                            while ((length = stream.Read(bytes, 0, bytes.Length)) != 0)
                            {
                                var incommingData = new byte[length];
                                Array.Copy(bytes, 0, incommingData, 0, length);
                                string serverMessage = Encoding.ASCII.GetString(incommingData);
                                Debug.WriteLine("RECIEVED: " + serverMessage);

                                if (serverMessage.Contains("CONNECTED"))
                                {
                                    UpdateStatusLabel("Connected. Validating server configs.");

                                    string[] temp = serverMessage.Split('|');

                                    AC = new Anticheat(temp[1].Trim());

                                    if(!AC.CanConnect())
                                    {
                                        socketConnection.Close();
                                        UpdateStatusLabel("Disconnected.");
                                        UpdateJoinCodeLabel("");
                                    }
                                    else
                                    {
                                        UpdateStatusLabel("Validated. Waiting for player to join.");
                                    }
                                }
                                else if (serverMessage.Contains("WELCOME"))
                                {
                                    string[] temp = serverMessage.Split(':');
                                    UpdateStatusLabel("In the server");
                                    UpdateUserInfoLabels(temp[1]);
                                }
                                else if (serverMessage == "PING")
                                {
                                    string pongMsg = string.Empty;

                                    if (AC.req.info.gtaRunning && !AC.IsRunningGTALegit())
                                    {
                                        pongMsg = string.Format("DROP:{0}", p.uniqueID);
                                    }
                                    else if(AC.req.info.sampRunning && !AC.IsSAMPRunning())
                                    {
                                        pongMsg = string.Format("DROP:{0}", p.uniqueID);
                                    }
                                    else if(AC.req.info.monitorProcessesConstantly && !AC.ProcessesClean())
                                    {
                                        pongMsg = string.Format("DROP:{0}", p.uniqueID);
                                    }
                                    else
                                    {
                                        pongMsg = string.Format("PONG:{0}", p.uniqueID);
                                    }

                                    SendMessage(pongMsg);
                                }
                                else if (serverMessage == "DSCN")
                                {
                                    socketConnection.Close();
                                    UpdateStatusLabel("Disconnected.");

                                    MethodInvoker action = delegate { labelPlayerName.Visible = false; };
                                    labelPlayerName.BeginInvoke(action);

                                    action = delegate { label1.Visible = false; };
                                    label1.BeginInvoke(action);

                                    UpdateJoinCodeLabel("");
                                }
                                else if(serverMessage == "WRONG_SEC_CODE")
                                {
                                    socketConnection.Close();
                                    UpdateStatusLabel("Disconnected. Versions don't match.");

                                    UpdateJoinCodeLabel("");
                                }
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        WriteLog(ex.ToString());
                        ToggleConnectButton(true);
                        break;
                    }
                }
            }
            catch (SocketException socketException)
            {
                UpdateStatusLabel("Could not connect. Check the logs.");
                ToggleConnectButton(true);
                WriteLog(socketException.ToString());
            }
        }

        private void materialRaisedButton2_Click(object sender, EventArgs e)
        {
            MessageBox.Show("bAnticheat client made by bruxo. Code avaliable at: github.com/bruxo00\n\nVersion 2.0", "About", MessageBoxButtons.OK);

        }

        private void Form1_FormClosing(object sender, FormClosingEventArgs e)
        {
            Environment.Exit(-1);
        }
    }
}
