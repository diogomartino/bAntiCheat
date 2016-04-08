using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Net.Sockets;
using System.Net;
using System.Diagnostics;
using System.IO;
using Microsoft.Win32;
using System.Threading;

namespace bAntiCheat
{
    public partial class Principal : Form
    {
        private static List<Socket> clientSockets = new List<Socket>();
        private static Socket serverSocket = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
        private static byte[] buffer = new byte[1024];
        private static Player Player = new Player();
        private static string gtaPath = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData).ToString() + @"\path.txt";
        private static Config Cfg = new Config();

        /// <summary>
        /// Builder principal
        /// </summary>
        public Principal()
        {
            try
            {
                InitializeComponent();

                richTextBox1.AppendText("A carregar o anticheat...");

                string allPath = string.Empty;

                using (RegistryKey registryKey = Registry.CurrentUser.OpenSubKey(@"SOFTWARE\SAMP"))
                {
                    allPath = (string)registryKey.GetValue("gta_sa_exe");
                }

                gtaPath = allPath.Replace(@"\gta_sa.exe", "");

                if (gtaPath.Length < 3)
                {
                    richTextBox1.AppendText("\nPasta do GTA não encontrada. Reinstale o SAMP e tente denovo");
                }

                if(Cfg.analisarOnStartup == true)
                {
                    if (VerificarCheats() == true)
                    {
                        richTextBox1.AppendText("\nCheats detectados. Remova todos os ficheiros relacionados a cheats do seu PC e de seguida tente novamente.");
                        return;
                    }
                }

                SetupServer();
            }
            catch (Exception ex)
            {
                richTextBox1.AppendText("Erro: " + ex.ToString());
            }
        }

        /// <summary>
        /// Escreve no mainthread de threads secundários
        /// </summary>
        /// <param name="text"></param>
        public void AppendText(string text)
        {
            MethodInvoker action = delegate { richTextBox1.Text += "\n" + text; };
            richTextBox1.BeginInvoke(action);
        }

        /// <summary>
        /// Inicia o servidor de sockets
        /// </summary>
        private void SetupServer()
        {
            try
            {
                serverSocket.Bind(new IPEndPoint(IPAddress.Any, 4000));
                serverSocket.Listen(1);
                serverSocket.BeginAccept(new AsyncCallback(AcceptCallback), null);

                richTextBox1.AppendText("\nÁ espera da conexão do servidor...");
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.ToString());
            }
        }

        /// <summary>
        /// Aceita a conexão do servidor
        /// </summary>
        /// <param name="AR"></param>
        private void AcceptCallback(IAsyncResult AR)
        {
            try
            {
                Socket socket = serverSocket.EndAccept(AR);
                clientSockets.Add(socket);

                AppendText("A receber ligação do servidor");

                socket.BeginReceive(buffer, 0, buffer.Length, SocketFlags.None, new AsyncCallback(ReceiveCallback), socket);
                serverSocket.BeginAccept(new AsyncCallback(AcceptCallback), null);
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.ToString());
            }
        }

        /// <summary>
        /// Interpreta a resposta do servidor
        /// </summary>
        /// <param name="AR"></param>
        private void ReceiveCallback(IAsyncResult AR)
        {
            try
            {
                Socket socket = (Socket)AR.AsyncState;
                int received = socket.EndReceive(AR);
                byte[] dataBuf = new byte[received];
                Array.Copy(buffer, dataBuf, received);

                string text = Encoding.UTF8.GetString(dataBuf);
                string status = string.Empty;

                if (text.Contains("connected")) // entrou no servidor, vai verificar se há cheats
                {
                    string sub_pID = Functions.GetBetween(text, "|", "|");
                    string serverVersion = Functions.GetBetween(text, ",", ",");

                    int pID;
                    Int32.TryParse(text, out pID);

                    Player.playerid = pID;

                    //MessageBox.Show("sub_pID: " + sub_pID + " | serverVersion: " + serverVersion + " | acVersion: " + Cfg.acVersion);

                    if (serverVersion != Cfg.acVersion)
                    {
                        status = Player.playerid + "'updateneed'" + Player.UID;
                        AppendText("O teu anticheat está desactualizado.");
                        goto DATASEND;
                    }

                    AppendText("Bem vindo ao servidor. O teu playerid é " + pID + " .");

                    if (VerificarCheats() == true)
                    {
                        status = Player.playerid + "'cheater'" + Player.UID;
                    }
                    else
                    {
                        status = Player.playerid + "'secure'" + Player.UID;
                        Player.connected = true;
                    }
                }
                else if(text.Contains("disconnect")) 
                {
                    AppendText("Saíste do servidor.");
                    Player.connected = false;
                    return;
                }
                else if (text.Contains("check")) 
                {
                    if(VerificarCheats() == true)
                    {
                        status = Player.playerid + "'cheater'" + Player.UID;
                    }
                    else
                    {
                        status = Player.playerid + "'online'" + Player.UID;
                    }
                }

                DATASEND:

                byte[] data = Encoding.UTF8.GetBytes(status);
                socket.BeginSend(data, 0, data.Length, SocketFlags.None, new AsyncCallback(SendCallback), socket);
                socket.BeginReceive(buffer, 0, buffer.Length, SocketFlags.None, new AsyncCallback(ReceiveCallback), socket);

            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.ToString());
            }
        }

        /// <summary>
        /// Envia uma resposta ao servidor
        /// </summary>
        /// <param name="AR"></param>
        private void SendCallback(IAsyncResult AR)
        {
            try
            {
                Socket socket = (Socket)AR.AsyncState;
                socket.EndSend(AR);
            }
            catch { }
        }

        /// <summary>
        /// Verifica se há cheats. Retorna TRUE caso haja e FALSE caso não haja
        /// </summary>
        private bool VerificarCheats()
        {
            try
            {
                foreach (string s in Directory.GetDirectories(gtaPath))
                {
                    string folderName = s.Remove(0, gtaPath.Length).Replace(@"\", "");

                    if (folderName.Contains("mod_sa", StringComparison.OrdinalIgnoreCase) ||
                       folderName.Contains("cleo", StringComparison.OrdinalIgnoreCase)) // s0beit
                    {
                        return true;
                    }
                }

                string[] filestwo = Directory.GetFiles(gtaPath + @"\data", "*.two").Select(path => Path.GetFileName(path)).ToArray();

                foreach (string s in filestwo)
                {
                    if (s.Contains("carmods", StringComparison.OrdinalIgnoreCase) ||
                        s.Contains("default", StringComparison.OrdinalIgnoreCase) ||
                        s.Contains("HANDLING", StringComparison.OrdinalIgnoreCase) ||
                        s.Contains("carmods", StringComparison.OrdinalIgnoreCase) ||
                        s.Contains("surface", StringComparison.OrdinalIgnoreCase) ||
                        s.Contains("timecyc", StringComparison.OrdinalIgnoreCase) ||
                        s.Contains("vehicles", StringComparison.OrdinalIgnoreCase))
                    {
                        return true;
                    }
                }

                string[] filesdll = Directory.GetFiles(gtaPath, "*.dll").Select(path => Path.GetFileName(path)).ToArray();

                foreach (string s in filesdll)
                {
                    if (s.Contains("d3d9", StringComparison.OrdinalIgnoreCase) ||
                        s.Contains("SaSa", StringComparison.OrdinalIgnoreCase))
                    {
                        return true;
                    }
                }

                string[] filesexe = Directory.GetFiles(gtaPath, "*.exe").Select(path => Path.GetFileName(path)).ToArray();

                foreach (string s in filesexe)
                {
                    if (s.Contains("mod_sa", StringComparison.OrdinalIgnoreCase))
                    {
                        return true;
                    }
                }

                Process[] processlist = Process.GetProcesses();

                foreach (Process process in processlist)
                {
                    if (process.ProcessName.Contains("samphacktool") ||
                       process.ProcessName.Contains("trainer") ||
                       process.ProcessName.Contains("cheatengine") ||
                       process.ProcessName.Contains("buzaglo") ||
                       process.ProcessName.Contains("aimbot") ||
                       process.ProcessName.Contains("bot") ||
                       process.ProcessName.Contains("injector") ||
                       (process.ProcessName.Contains("samp") && (process.ProcessName.Contains("hack") || process.ProcessName.Contains("mod"))))
                    {
                        return true;
                    }
                }
            }
            catch (Exception ex)
            {
                AppendText("Erro: " + ex.ToString());
            }

            return false;
        }

        private void fusionButton2_Click(object sender, EventArgs e)
        {
            Environment.Exit(-1);
        }

        private void fusionButton3_Click(object sender, EventArgs e)
        {
            MessageBox.Show("Criado por bruxo\nVersão 1.0 Alpha", "ABOUT", MessageBoxButtons.OK);
        }

        private void fusionButton1_Click(object sender, EventArgs e)
        {
            MessageBox.Show("Próxima versão", "ABOUT", MessageBoxButtons.OK);
        }
    }

    static class Functions
    {
        /// <summary>
        /// Funciona da mesma maneira da string.Contains só que tem a opção de se Case Sensitive
        /// </summary>
        public static bool Contains(this string source, string toCheck, StringComparison comp)
        {
            return source != null && toCheck != null && source.IndexOf(toCheck, comp) >= 0;
        }

        /// <summary>
        /// Retorna a string entre uma string (strStart) e outra (strEnd)
        /// </summary>
        /// <param name="strSource"></param>
        /// <param name="strStart"></param>
        /// <param name="strEnd"></param>
        public static string GetBetween(string strSource, string strStart, string strEnd)
        {
            int Start, End;
            if (strSource.Contains(strStart) && strSource.Contains(strEnd))
            {
                Start = strSource.IndexOf(strStart, 0) + strStart.Length;
                End = strSource.IndexOf(strEnd, Start);
                return strSource.Substring(Start, End - Start);
            }
            else
            {
                return "";
            }
        }
    }
}
