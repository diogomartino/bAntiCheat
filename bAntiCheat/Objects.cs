using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Management;

namespace bAntiCheat
{
    class Player
    {
        public int playerid { get; set; }
        public bool connected { get; set; }
        public string UID { get; set; }

        public Player()
        {
            playerid = -1;
            connected = false;
            UID = GenerateUID();
        }
        
        private string GenerateUID()
        {
            string finalUID = string.Empty;

            var mbs = new ManagementObjectSearcher("Select ProcessorId From Win32_processor");
            ManagementObjectCollection mbsList = mbs.Get();
            string cpuID = "";
            foreach (ManagementObject mo in mbsList)
            {
                cpuID = mo["ProcessorId"].ToString();
                break;
            }

            ManagementObjectSearcher mos = new ManagementObjectSearcher("SELECT * FROM Win32_BaseBoard");
            ManagementObjectCollection moc = mos.Get();
            string mbID = "";
            foreach (ManagementObject mo in moc)
            {
                mbID = (string)mo["SerialNumber"];
            }

            finalUID = cpuID + mbID;

            return finalUID;
        }
    }

    class Config
    {
        public bool analisarOnStartup { get; set; }

        public Config()
        {
            analisarOnStartup = true;
        }
    }
}
