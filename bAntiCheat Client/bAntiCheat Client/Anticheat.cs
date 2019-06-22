using Microsoft.Win32;
using System;
using System.Diagnostics;
using System.Dynamic;
using System.IO;
using System.Security.Cryptography;
using System.Threading;
using System.Windows.Forms;

namespace bAntiCheat_Client
{
    class Anticheat
    {
        public Request req;
        private string schemaUrl { get; set; }

        public Anticheat(string schemaUrl)
        {
            this.schemaUrl = schemaUrl;
        }

        public bool ProcessesClean()
        {
            dynamic forbiddenProcessesResponse = CheckForbiddenProcesses();

            if (forbiddenProcessesResponse.passed == false)
            {
                ThreadPool.QueueUserWorkItem(delegate { // prevents not getting drop if player doesn't click on the message
                    MessageBox.Show("Forbidden process detected." +
                    "\n\nProcess: " + forbiddenProcessesResponse.process.name + ".exe", "Alert", MessageBoxButtons.OK, MessageBoxIcon.Exclamation);
                });

                return false;
            }

            return true;
        }

        public bool CanConnect()
        {
            req = new Request(schemaUrl);
            bool clean = true;

            try
            {
                if (req.info != null)
                {
                    dynamic validateFilesResponse = ValidateFiles();
                    dynamic forbiddenFilesResponse = CheckForbiddenFiles();
                    dynamic forbiddenDirectoriesResponse = CheckForbiddenDirectories();
                    dynamic forbiddenProcessesResponse = CheckForbiddenProcesses();

                    if (validateFilesResponse.passed == false)
                    {
                        if (validateFilesResponse.file.action == "PREVENT_CONNECT")
                        {
                            MessageBox.Show("Changed gamefiles detected." +
                            "\n\nFile: " + validateFilesResponse.file.path +
                            "\nReason: " + validateFilesResponse.reason, "Alert", MessageBoxButtons.OK, MessageBoxIcon.Exclamation);

                            clean = false;
                        }
                    }

                    if (forbiddenDirectoriesResponse.passed == false)
                    {
                        if (forbiddenDirectoriesResponse.directory.action == "PREVENT_CONNECT")
                        {
                            MessageBox.Show("Forbidden directory detected." +
                            "\n\nDirectory: " + forbiddenDirectoriesResponse.directory.path, "Alert", MessageBoxButtons.OK, MessageBoxIcon.Exclamation);

                            clean = false;
                        }
                    }

                    if (forbiddenFilesResponse.passed == false)
                    {
                        if (forbiddenFilesResponse.file.action == "PREVENT_CONNECT")
                        {
                            MessageBox.Show("Forbidden file detected." +
                            "\n\nFile: " + forbiddenFilesResponse.file.path, "Alert", MessageBoxButtons.OK, MessageBoxIcon.Exclamation);

                            clean = false;
                        }
                    }

                    if (forbiddenProcessesResponse.passed == false)
                    {
                        if (forbiddenProcessesResponse.process.action == "PREVENT_CONNECT")
                        {
                            MessageBox.Show("Forbidden process detected." +
                            "\n\nProcess: " + forbiddenProcessesResponse.process.name + ".exe", "Alert", MessageBoxButtons.OK, MessageBoxIcon.Exclamation);

                            clean = false;
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Form1.WriteLog(ex.ToString());
            }
  

            return clean;
        }

        public static string GetChecksum(string file)
        {
            using (FileStream stream = File.OpenRead(file))
            {
                var sha = new SHA256Managed();
                byte[] checksum = sha.ComputeHash(stream);
                stream.Close();
                return BitConverter.ToString(checksum).Replace("-", String.Empty);
            }
        }

        public object ValidateFiles()
        {
            string gtaPath = GetGTADirectory();

            dynamic response = new ExpandoObject();
            response.passed = true;
            response.file = null;

            foreach (Validationfile file in req.info.validationFiles)
            {
                string filePath = Path.Combine(gtaPath, file.path);

                if (!File.Exists(filePath))
                {
                    response.passed = false;
                    response.file = file;
                    response.reason = "file doesn't exist";
                    break;
                }
                else
                {
                    string checksum = GetChecksum(filePath);
                    if (checksum != file.hash.ToUpper())
                    {
                        response.passed = false;
                        response.file = file;
                        response.reason = "checksum differs from original";
                        break;
                    }
                }
            }

            return response;
        }

        public object CheckForbiddenFiles()
        {
            string gtaPath = GetGTADirectory();

            dynamic response = new ExpandoObject();
            response.passed = true;
            response.file = null;

            foreach (Forbiddenfile file in req.info.forbiddenFiles)
            {
                string filePath = Path.Combine(gtaPath, file.path);

                if (File.Exists(filePath))
                {
                    response.passed = false;
                    response.file = file;
                    break;
                }
            }

            return response;
        }

        public object CheckForbiddenProcesses()
        {
            dynamic response = new ExpandoObject();
            response.passed = true;
            response.process = null;

            foreach (Forbiddenprocess process in req.info.forbiddenProcesses)
            {
                foreach(Process p in Process.GetProcessesByName(process.name))
                {
                    response.passed = false;
                    response.process = process;
                    break;
                }
            }

            return response;
        }

        public object CheckForbiddenDirectories()
        {
            string gtaPath = GetGTADirectory();

            dynamic response = new ExpandoObject();
            response.passed = true;
            response.directory = null;

            foreach (Forbiddenndirectory directory in req.info.forbiddenDirectories)
            {
                string directoryPath = Path.Combine(gtaPath, directory.path);

                if (Directory.Exists(directoryPath))
                {
                    response.passed = false;
                    response.directory = directory;
                    break;
                }
            }

            return response;
        }

        public static string GetGTADirectory()
        {
            try
            {
                using (RegistryKey registryKey = Registry.CurrentUser.OpenSubKey(@"SOFTWARE\SAMP"))
                {
                    return registryKey.GetValue("gta_sa_exe").ToString().Trim().Replace("\\gta_sa.exe", "");
                }
            }
            catch
            {
                return null;
            }
        }

        public static string GetGTAPath()
        {
            try
            {
                using (RegistryKey registryKey = Registry.CurrentUser.OpenSubKey(@"SOFTWARE\SAMP"))
                {
                    return registryKey.GetValue("gta_sa_exe").ToString().Trim();
                }
            }
            catch
            {
                return null;
            }
        }

        public bool IsRunningGTALegit()
        {
            foreach (Process p in Process.GetProcessesByName("gta_sa"))
            {
                if(p.MainModule.FileName != GetGTAPath())
                {
                    return false;
                }
                else
                {
                    return true;
                }
            }

            return false;
        }

        public bool IsGTARunning()
        {
            foreach(Process p in Process.GetProcessesByName("gta_sa"))
            {
                return true;
            }

            return false;
        }

        public bool IsSAMPRunning()
        {
            foreach (Process p in Process.GetProcessesByName("samp"))
            {
                return true;
            }

            return false;
        }

    }
}
