Add-Type @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace PInvoke.Win32 {

    public static class UserInput {

        [DllImport("user32.dll", SetLastError=false)]
        private static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

        [StructLayout(LayoutKind.Sequential)]
        private struct LASTINPUTINFO {
            public uint cbSize;
            public int dwTime;
        }

        public static DateTime LastInput {
            get {
                DateTime bootTime = DateTime.UtcNow.AddMilliseconds(-Environment.TickCount);
                DateTime lastInput = bootTime.AddMilliseconds(LastInputTicks);
                return lastInput;
            }
        }

        public static TimeSpan IdleTime {
            get {
                return DateTime.UtcNow.Subtract(LastInput);
            }
        }

        public static int LastInputTicks {
            get {
                LASTINPUTINFO lii = new LASTINPUTINFO();
                lii.cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO));
                GetLastInputInfo(ref lii);
                return lii.dwTime;
            }
        }
    }
}
'@

$wshell = New-Object -ComObject wscript.shell;
$threshold = 60
$sleeptime = 20

While ($true) {
    $idle = [PInvoke.Win32.UserInput]::IdleTime.TotalSeconds
    $lastinput = [PInvoke.Win32.UserInput]::LastInput
    $last_action = "none"

    if ($idle -gt $threshold){
        if($wshell.AppActivate('Unbenannt - Editor')) {
            $wshell.SendKeys('ABCDEFGHIJKLMNOPQRSTUVWXYZ')
            Sleep 0.1
            $wshell.SendKeys('^A')
            $wshell.SendKeys('{BKSP}')
            $last_action = "press keys"
        } else {
            Start-Process -FilePath "C:\WINDOWS\system32\notepad.exe"
            $last_action = "open editor"
        }
    } else {
        last_action = "no action"
    }

    Clear-Host
    "Last Response from User: $lastinput"
    "Seconds since last input: $idle"
    "Last Action = $last_action"

    Sleep $sleeptime
    Sleep 1
}
