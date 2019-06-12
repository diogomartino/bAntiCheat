using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Management;
using System.Net.NetworkInformation;
using System.Text;
using System.Windows.Forms;

namespace bAntiCheat_Client
{
    class Player
    {
        public string uniqueID { get; set; }
        public string securityID { get; set; }
        public int joinCode { get; set; }

        public Player()
        {
            uniqueID = getUniqueID();
            securityID = getSecurityID();
            joinCode = 0000;

            Debug.WriteLine("Security ID: " + securityID);
        }

        public void generateNewJoinCode()
        {
            Random rand = new Random();
            joinCode = rand.Next(10000, 99999);
        }

        private string getSecurityID()
        {
            string exePath = Application.ExecutablePath;;
            return Anticheat.GetChecksum(exePath);
        }

        private string getUniqueID()
        {
            string cpuInfo = string.Empty;
            string ramInfo = string.Empty;
            string gpuInfo = string.Empty;

            ManagementClass mc = new ManagementClass("Win32_Processor");
            ManagementObjectCollection moc = mc.GetInstances();

            foreach (ManagementObject mo in moc)
            {
                try
                {
                    cpuInfo = mo.Properties["SerialNumber"].Value.ToString().Trim();
                }
                catch { }

                break;
            }

            mc = new ManagementClass("Win32_PhysicalMemory");
            moc = mc.GetInstances();

            foreach (ManagementObject mo in moc)
            {
                try
                {
                    ramInfo = mo.Properties["SerialNumber"].Value.ToString().Trim();
                }
                catch { }

                break;
            }

            mc = new ManagementClass("Win32_VideoController");
            moc = mc.GetInstances();

            foreach (ManagementObject mo in moc)
            {
                try
                {
                    gpuInfo = mo.Properties["Name"].Value.ToString().Trim();
                }
                catch { }

                break;
            }

            if(string.IsNullOrEmpty(cpuInfo) && string.IsNullOrEmpty(gpuInfo) && string.IsNullOrEmpty(ramInfo))
            {
                return sha256(NetworkInterface.GetAllNetworkInterfaces().Where(nic => nic.OperationalStatus == OperationalStatus.Up).Select(nic => nic.GetPhysicalAddress().ToString()).FirstOrDefault().Trim());
            }

            return sha256(cpuInfo + gpuInfo + ramInfo);
        }

        private string sha256(string str)
        {
            var crypt = new System.Security.Cryptography.SHA256Managed();
            var hash = new StringBuilder();
            byte[] crypto = crypt.ComputeHash(Encoding.UTF8.GetBytes(str));
            foreach (byte theByte in crypto)
            {
                hash.Append(theByte.ToString("x2"));
            }
            return hash.ToString();
        }
    }
}
