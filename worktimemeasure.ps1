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
$thresholdSeconds = 60
$sleepTimeSeconds = 20
$startTime = Get-Date
$afkTimespan = New-TimeSpan

$afk = $false # True, wenn der Rechner bei der letzten Iteration gesperrt war
$afkStart = $null

# Change Window Size
[console]::WindowHeight = 4
[console]::WindowWidth = 20
[console]::BufferWidth=[console]::WindowWidth

While ($true) {
    $locked = Get-Process logonui -ErrorAction SilentlyContinue ## locked -ne $null, wenn der Rechner gesperrt ist
    if($locked -ne $null -and -not $afk) {
        # Nutzer ist AFK gegangen
        $afk = $true

        $afkStart = Get-Date # Startzeit erfassen
    } elseif ($locked -eq $null -and $afk) { ## locked -eq $null, wenn der Rechner NICHT gesperrt ist
        # Nutzer ist wieder da
        $afk = $false

        $afkTimespan += New-Timespan -Start $afkStart
    } elseif ($locked -eq $null) {
        # Rechner ist schon länger (min. 20 Sekunden) nicht gesperrt 
        $idleSeconds = [PInvoke.Win32.UserInput]::IdleTime.TotalSeconds

        if ($idleSeconds -gt $thresholdSeconds){
            $wshell.SendKeys("{SCROLLLOCK}")
            Sleep 0.1
            $wshell.SendKeys("{SCROLLLOCK}")
        }
    }

    $attendanceTime = New-TimeSpan -Start $startTime
    $paidTime = $attendanceTime - $afkTimespan

    Clear-Host
    "Anwesenheit: " + $attendanceTime.toString("hh\:mm")
    "Abwesenheit: " + $afkTimespan.toString("hh\:mm")
    "Arbeitszeit: " + $paidTime.toString("hh\:mm")

    # Sleepcycle
    Sleep $sleepTimeSeconds
    Sleep 1
}
