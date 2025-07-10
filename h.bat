@echo off

:: Check for admin rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs -WindowStyle Hidden"
    exit /b
)

:: Run the PowerShell silently and close when done
powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -Command ^
"try { ^
    [Windows.System.UserProfile.LockScreen,Windows.System.UserProfile,ContentType=WindowsRuntime] ^| Out-Null; ^
    Add-Type -AssemblyName System.Runtime.WindowsRuntime; ^
    $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() ^| ? { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]; ^
    Function Await($WinRtTask, $ResultType) { ^
        $asTask = $asTaskGeneric.MakeGenericMethod($ResultType); ^
        $netTask = $asTask.Invoke($null, @($WinRtTask)); ^
        $netTask.Wait(-1) ^| Out-Null; ^
        $netTask.Result ^
    }; ^
    $connectionProfile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile(); ^
    $tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile($connectionProfile); ^
    if ($tetheringManager.TetheringOperationalState -ne 'On') { ^
        $result = Await ($tetheringManager.StartTetheringAsync()) ([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult]); ^
        if ($result.Status -ne 'Success') { ^
            Add-Type -AssemblyName System.Windows.Forms; ^
            [System.Windows.Forms.MessageBox]::Show(\"failed: $($result.Status) - $($result.AdditionalErrorMessage)\", 'Error', 'OK', 'Error') ^
        } else { ^
            Start-Sleep -Seconds 2; ^
            Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public class M{[DllImport(\"user32.dll\")]public static extern int SendMessage(IntPtr h,int m,int w,int l);public static void T(){SendMessage((IntPtr)0xFFFF,0x0112,0xF170,2);}}'; ^
            [M]::T() ^
        } ^
    } ^
} catch { ^
    Add-Type -AssemblyName System.Windows.Forms; ^
    [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Script Error', 'OK', 'Error') ^
}"

exit
