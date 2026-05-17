try {
    # Load Windows Runtime system extensions
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    
    # Pre-load needed WinRT types with correct class names
    [Void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType=WindowsRuntime]
    [Void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties, Windows.Media.Control, ContentType=WindowsRuntime]

    # Helper function to handle async calls in PowerShell
    $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { 
        $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' 
    })[0]

    Function Await($WinRtTask, $ResultType) {
        $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
        $netTask = $asTask.Invoke($null, @($WinRtTask))
        $netTask.Wait(-1) | Out-Null
        return $netTask.Result
    }

    $sessionManager = Await ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])
    $currentSession = $sessionManager.GetCurrentSession()

    if ($null -ne $currentSession) {
        $mediaProperties = Await ($currentSession.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
        Write-Output "$($mediaProperties.Artist)::$($mediaProperties.Title)::$($mediaProperties.AlbumTitle)"
    } else {
        Write-Output "NONE"
    }
} catch {
    Write-Output "ERROR::$_"
}
