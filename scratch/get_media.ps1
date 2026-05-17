try {
    # Load Windows Runtime system extensions
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    
    # Pre-load needed WinRT types with correct class names
    [Void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType=WindowsRuntime]
    [Void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties, Windows.Media.Control, ContentType=WindowsRuntime]
    [Void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionTimelineProperties, Windows.Media.Control, ContentType=WindowsRuntime]
    [Void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionPlaybackInfo, Windows.Media.Control, ContentType=WindowsRuntime]

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
        
        # Get Playback Info (Is playing?)
        $playback = $currentSession.GetPlaybackInfo()
        $isPlaying = "false"
        $rate = 1.0
        if ($null -ne $playback) {
            # Direct integer check or string enum check
            if ($playback.PlaybackStatus -eq "Playing" -or $playback.PlaybackStatus -eq 4) {
                $isPlaying = "true"
            } else {
                $rate = 0.0 # If paused/stopped, time doesn't elapse
            }
            if ($null -ne $playback.PlaybackRate) {
                $rate = $rate * $playback.PlaybackRate
            }
        }

        # Get Timeline Info
        $timeline = $currentSession.GetTimelineProperties()
        $position = 0.0
        $duration = 0.0
        if ($null -ne $timeline) {
            $snapshotPosition = $timeline.Position.TotalSeconds
            $lastUpdated = $timeline.LastUpdatedTime # A System.DateTimeOffset
            $duration = $timeline.EndTime.TotalSeconds

            # Calculate actual current position based on elapsed time since LastUpdatedTime
            $now = [System.DateTimeOffset]::Now
            $elapsed = ($now - $lastUpdated).TotalSeconds
            
            # Position = snapshot + (elapsed * rate)
            $position = $snapshotPosition + ($elapsed * $rate)

            # Clamp position
            if ($position -gt $duration) {
                $position = $duration
            }
            if ($position -lt 0) {
                $position = 0.0
            }
        }

        Write-Output "$($mediaProperties.Artist)::$($mediaProperties.Title)::$($mediaProperties.AlbumTitle)::$position::$duration::$isPlaying"
    } else {
        Write-Output "NONE"
    }
} catch {
    Write-Output "ERROR::$_"
}
