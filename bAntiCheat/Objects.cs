using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Management;
using System.Security.Cryptography;
using System.IO;

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
        public string acVersion { get; set; }
        public string md5Hash { get; set; }

        public Config()
        {
            analisarOnStartup = true;
            acVersion = "1.0.1";
            md5Hash = checkMD5(System.Reflection.Assembly.GetEntryAssembly().Location);
        }

        /// <summary>
        /// Retorna a hash MD5 de um ficheiro
        /// </summary>
        /// <param name="filename"></param>
        private string checkMD5(string filename)
        {
            using (var md5 = MD5.Create())
            {
                using (var stream = File.OpenRead(filename))
                {
                    string md5Hash = Encoding.UTF8.GetString(md5.ComputeHash(stream));
                    byte[] md5Byte = Encoding.UTF8.GetBytes(md5Hash);
                    string md5Binary = ToBinary(md5Byte);
                    return md5Binary;
                }
            }
        }

        private string ToBinary(byte[] data)
        {
            return string.Join(" ", data.Select(byt => Convert.ToString(byt, 2).PadLeft(8, '0')));
        }
    }
}
