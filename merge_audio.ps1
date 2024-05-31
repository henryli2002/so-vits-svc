# 设置目录路径
$directory = "D:\Project\CodeProject\so-vits-svc\results"

# 导航到指定目录
Write-Output "Navigating to $directory"
cd $directory

# 获取目录中的所有 WAV 和 FLAC 文件
$wavFiles = Get-ChildItem -Filter *.wav
$flacFiles = Get-ChildItem -Filter *.flac

# 将所有 FLAC 文件转换为 WAV 文件
$ffmpegPath = "ffmpeg" # 使用系统路径中的 ffmpeg
foreach ($flacFile in $flacFiles) {
    $wavFile = [System.IO.Path]::ChangeExtension($flacFile.FullName, ".wav")
    $convertCommand = "$ffmpegPath -i `"$($flacFile.FullName)`" `"$($wavFile)`""
    Write-Output "Converting $($flacFile.FullName) to $wavFile"
    Start-Process -FilePath $ffmpegPath -ArgumentList "-i `"$($flacFile.FullName)`" `"$($wavFile)`"" -NoNewWindow -Wait
    Remove-Item $flacFile.FullName
}

# 更新 WAV 文件列表以包含新转换的文件
$wavFiles = Get-ChildItem -Filter *.wav
Write-Output "Found $($wavFiles.Count) wav files"

# 创建一个字典，用于存储前两个字符相同的文件列表
$fileGroups = @{}

foreach ($file in $wavFiles) {
    # 获取文件的前两个字符
    $prefix = $file.BaseName.Substring(0, 3)

    # 如果字典中不存在该前缀，创建一个新的列表
    if (-not $fileGroups.ContainsKey($prefix)) {
        $fileGroups[$prefix] = @()
    }

    # 将文件添加到对应前缀的列表中
    $fileGroups[$prefix] += $file.FullName
}

# 输出文件分组信息
foreach ($prefix in $fileGroups.Keys) {
    Write-Output "${prefix}: $($fileGroups[$prefix] -join ', ')"
}

# 合并前两个字符相同的文件
foreach ($prefix in $fileGroups.Keys) {
    $group = $fileGroups[$prefix]
    
    # 只处理恰好包含两个文件的组
    if ($group.Count -eq 2) {
        $input1 = $group[0]
        $input2 = $group[1]
        
        # 获取文件名长度
        $len1 = [System.IO.Path]::GetFileNameWithoutExtension($input1).Length
        $len2 = [System.IO.Path]::GetFileNameWithoutExtension($input2).Length
        
        # 设置音量调整命令
        if ($len1 -gt $len2) {
            $volumeFilter = "[0]volume=2[a];[a][1]amix=inputs=2:duration=longest"
        } else {
            $volumeFilter = "[1]volume=2[a];[0][a]amix=inputs=2:duration=longest"
        }

        # 构建输出文件路径
        $shortName = if ($len1 -le $len2) { [System.IO.Path]::GetFileNameWithoutExtension($input1) } else { [System.IO.Path]::GetFileNameWithoutExtension($input2) }
        # 移除非法字符
        $shortName = $shortName -replace '[^\w\.-]', '_'
        $outputFile = "$directory\$shortName.wav"
        
        $command = "$ffmpegPath -i `"$input1`" -i `"$input2`" -filter_complex `"$volumeFilter`" `"$outputFile`""
        Write-Output "Merging $input1 and $input2 into $outputFile with command: $command"
        Start-Process -FilePath $ffmpegPath -ArgumentList "-i `"$input1`" -i `"$input2`" -filter_complex `"$volumeFilter`" `"$outputFile`"" -NoNewWindow -Wait
        
        # 删除原始文件
        Remove-Item $input1
        Remove-Item $input2
    }
}
