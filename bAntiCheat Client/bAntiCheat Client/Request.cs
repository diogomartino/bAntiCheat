using Newtonsoft.Json;
using System;
using System.Net;
using System.Windows.Forms;

namespace bAntiCheat_Client
{
    class Request
    {
        public Rootobject info;
        private string schemaUrl { get; set; }

        public Request(string schemaUrl)
        {
            this.schemaUrl = schemaUrl;

            try
            {
                using (WebClient client = new WebClient())
                {
                    string jsonStr = client.DownloadString(schemaUrl);
                    info = JsonConvert.DeserializeObject<Rootobject>(jsonStr);
                }

            }
            catch (Exception ex)
            {
                Form1.WriteLog(ex.ToString());
                MessageBox.Show("There was a problem parsing server configs.");
            }
        }
    }

    public class Rootobject
    {
        public bool gtaRunning { get; set; }
        public bool sampRunning { get; set; }
        public bool monitorProcessesConstantly { get; set; }
        public Validationfile[] validationFiles { get; set; }
        public Forbiddenfile[] forbiddenFiles { get; set; }
        public Forbiddenndirectory[] forbiddenDirectories { get; set; }
        public Forbiddenprocess[] forbiddenProcesses { get; set; }
    }

    public class Validationfile
    {
        public string path { get; set; }
        public string hash { get; set; }
        public string action { get; set; }
    }

    public class Forbiddenfile
    {
        public string path { get; set; }
        public string action { get; set; }
    }

    public class Forbiddenndirectory
    {
        public string path { get; set; }
        public string action { get; set; }
    }

    public class Forbiddenprocess
    {
        public string name { get; set; }
        public string action { get; set; }
    }

}
