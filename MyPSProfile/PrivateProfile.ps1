using namespace System.Management.Automation
using namespace System.Management.Automation.Language


function local:Get-ObjectDetails
{
	[CmdletBinding(DefaultParameterSetName = 'Default')]
	[OutputType([PSCustomObject[]])]
	param(
		[Parameter(ParameterSetName = 'Default', Position = 0, Mandatory, HelpMessage = '要查找的对象名称或路径。可以是别名、命令、函数或文件路径。')]
		[Alias('Name', 'Path')]
		[String]$ObjectName,

		[Parameter(ParameterSetName = 'Default', Mandatory = $false, HelpMessage = '强制查找，即使对象不存在也继续执行。')]
		[Alias('F')]
		[Switch]$Force
	)

	begin
	{
		function Format-CustomObject
		{
			[CmdletBinding()]
			param(
				[Parameter(ValueFromPipeline, Mandatory)]
				[PSCustomObject]$InputObject,

				[Parameter(Mandatory)]
				[int]$Index,

				[Parameter(Mandatory)]
				[int]$TotalCount
			)

			process
			{
				$ExcludedProps = 'FileVersionInfo', 'Parameters', 'ScriptBlock', 'OutputType', 'ParameterSets'
				$OrderedProps = [Ordered]@{}

				$Header = "$([char]0x1b)[42m        第 <$Index> 个，共 <$TotalCount> 个                             $([char]0x1b)[0m"
				$OrderedProps["$([char]0x1b)[42m "] = $Header

				$InputObject.PSObject.Properties | Where-Object {
					($_.Name -notin $ExcludedProps) -and $_.Value
				} | ForEach-Object {
					$value = $_.Value
					if ($_.Name -eq 'Definition' -and $value -is [string])
					{
						$value = $value.Trim()
					}
					$OrderedProps[$_.Name] = $value
				}

				if ($OrderedProps['CommandType'] -eq 'Function')
				{
					$OrderedProps.Remove('Definition')
				}

				[PSCustomObject]$OrderedProps
			}
		}
	}

	process
	{
		try
		{
			$Items = @()
			$Items += $(Get-Alias -Definition $ObjectName -ErrorAction SilentlyContinue)
			$Items += $(Get-Command -Name $ObjectName -All -ErrorAction SilentlyContinue)
			$Items += $(Get-Item -Path $ObjectName -Force:$Force -ErrorAction SilentlyContinue)

			$UniqueItems = $Items | Where-Object { $_ }

			if (!$UniqueItems)
			{
				throw "未找到对象 '$ObjectName'"
			}

			$Index = 1
			$UniqueItems | ForEach-Object {
				$_ | Format-CustomObject -Index $Index -TotalCount $UniqueItems.Count
				$Index++
			}
		}
		catch
		{
			Write-Error -Message $_.Exception.Message -ErrorAction Continue
		}
	}

	end
	{
	}
}


function local:Add-CppFormatFile
{
	[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Default', ConfirmImpact = 'Medium')]
	[OutputType([Void])]
	param(
		[Parameter(ParameterSetName = 'Default', Position = 0, HelpMessage = '要添加 .clang-format 文件的目标目录路径。如果省略，则使用当前目录。')]
		[Alias('Path', 'To')]
		[String]$TargetPath,

		[Parameter(ParameterSetName = 'Default', HelpMessage = '指定 .clang-format 源文件的完整路径。')]
		[String]$SourceFile = 'D:\ProgramData\Working Projects\Projects for GitResources\CodeFormatFile\.clang-format'
	)

	begin
	{
		Write-Verbose '函数 Add-CppFormatFile 已启动。'
	}

	process
	{
		try
		{
			if ([String]::IsNullOrEmpty($TargetPath))
			{
				$TargetPath = Get-Location
				Write-Verbose "未提供目标目录，将使用当前目录: '$($TargetPath.Path)'"
			}

			Write-Verbose "正在验证目标目录 '$TargetPath' 是否存在..."
			if (-not (Test-Path -Path $TargetPath -PathType Container))
			{
				Write-Error -Message "操作中止：目标路径 '$TargetPath' 不是一个有效的目录。" -Category InvalidArgument
				return
			}

			$AbsoluteTargetPath = Convert-Path -Path $TargetPath

			Write-Verbose "正在验证源文件 '$SourceFile' 是否存在..."
			if (-not (Test-Path -Path $SourceFile -PathType Leaf))
			{
				Write-Error -Message "操作中止：源文件 '$SourceFile' 不存在或不是一个文件。" -Category ObjectNotFound
				return
			}

			$AbsoluteSourceFile = Convert-Path -Path $SourceFile

			$FinalLinkPath = Join-Path -Path $AbsoluteTargetPath -ChildPath '.clang-format'

			$actionMessage = "在目录 '$AbsoluteTargetPath' 中创建指向 '$AbsoluteSourceFile' 的符号链接"
			$targetResource = $FinalLinkPath

			if ($pscmdlet.ShouldProcess($targetResource, $actionMessage))
			{
				try
				{
					$null = New-Item -ItemType SymbolicLink -Path $FinalLinkPath -Value $AbsoluteSourceFile -Force -ErrorAction Stop
					Write-Host "成功添加 .clang-format 文件: '$FinalLinkPath' ==> '$AbsoluteSourceFile'" -ForegroundColor Green
				}
				catch
				{
					Write-Error -Message "创建 .clang-format 符号链接失败！错误信息: $($_.Exception.Message)"
				}
			}
		}
		catch
		{
			Write-Error -Message "在添加 .clang-format 文件时发生意外错误: $($_.Exception.Message)"
		}
	}

	end
	{
		Write-Verbose '函数 Add-CppFormatFile 执行完毕。'
	}
}


function local:Set-ObjectLink
{
	[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'SymbolicLinkParameterSet', ConfirmImpact = 'Medium')]
	[OutputType([Void])]
	param(
		[Parameter(Position = 0, Mandatory, HelpMessage = '要创建的链接的路径。如果它是一个目录，则链接将在此目录下创建。')]
		[Alias('Path')]
		[String]$Link,

		[Parameter(Position = 1, HelpMessage = '链接将要指向的目标文件或目录。如果省略，则第一个参数将被视为目标。')]
		[Alias('Value')]
		[String]$Target,

		[Parameter(HelpMessage = "为新创建的链接指定一个名称。仅当 'Link' 参数为目录时生效。")]
		[Alias('Name')]
		[String]$LinkName,

		[Parameter(ParameterSetName = 'SymbolicLinkParameterSet', Mandatory, HelpMessage = '指定创建【符号链接】(软链接) 。')]
		[Switch]$SymbolicLink,

		[Parameter(ParameterSetName = 'HardLinkParameterSet', Mandatory, HelpMessage = '指定创建【硬链接】。')]
		[Switch]$HardLink
	)

	begin
	{
		Write-Verbose '函数 Set-ObjectLink 已启动。'
	}

	process
	{
		try
		{
			if ([String]::IsNullOrEmpty($Target))
			{
				Write-Verbose "未提供目标(Target)，将把第一个参数 '$Link' 视为目标，并在当前目录下创建链接。"
				$Target = $Link
				$Link = Get-Location
			}

			Write-Verbose "正在验证目标路径 '$Target'..."
			if (-not (Test-Path -Path $Target))
			{
				Write-Error -Message "操作中止：不能把不存在的项 '$Target' 作为链接目标。" -Category ObjectNotFound
				return
			}

			$AbsoluteTarget = Convert-Path -Path $Target

			if ((Test-Path -Path $Link) -and (Get-Item $Link).PSIsContainer)
			{
				$TargetName = Split-Path -Path $AbsoluteTarget -Leaf
				Write-Verbose "提供的链接路径 '$Link' 是一个目录，将在此目录下创建链接。"

				if ([String]::IsNullOrEmpty($LinkName))
				{
					$LinkName = $TargetName
					Write-Verbose "未指定链接名称，将使用目标名称 '$LinkName' 作为默认名称。"
				}

				$FinalLinkPath = Join-Path -Path $(Convert-Path -Path $Link) -ChildPath $LinkName
			}
			else
			{
				Write-Verbose "提供的链接路径 '$Link' 将被用作新链接的完整路径。"
				$FinalLinkPath = $Link
				$LinkParentDir = Split-Path -Path $FinalLinkPath -Parent

				if (-not (Test-Path -Path $LinkParentDir))
				{
					Write-Error -Message "操作中止：链接所在的目录 '$LinkParentDir' 不存在。" -Category InvalidArgument
					return
				}
			}

			if (Test-Path -Path $FinalLinkPath)
			{
				Write-Error -Message "操作中止：目标链接路径 '$FinalLinkPath' 已经存在一个文件或目录。" -Category ResourceExists
				return
			}

			$ActionMessage = ''
			$LinkTypeForMessage = ''
			$ItemTypeForNewItem = ''

			if ($PSCmdlet.ParameterSetName -eq 'SymbolicLinkParameterSet')
			{
				$LinkTypeForMessage = '符号链接'
				$ItemTypeForNewItem = 'SymbolicLink'
			}
			else
			{
				$LinkTypeForMessage = '硬链接'
				$ItemTypeForNewItem = 'HardLink'
			}

			$ActionMessage = "创建【$LinkTypeForMessage】从 '$FinalLinkPath' 指向 '$AbsoluteTarget'"

			if ($pscmdlet.ShouldProcess($FinalLinkPath, $ActionMessage))
			{
				try
				{
					$null = New-Item -ItemType $ItemTypeForNewItem -Path $FinalLinkPath -Target $AbsoluteTarget -Force -ErrorAction Stop
					Write-Host "成功创建【$LinkTypeForMessage】：'$FinalLinkPath' ==> '$AbsoluteTarget'" -ForegroundColor Green
				}
				catch
				{
					Write-Error -Message "创建【$LinkTypeForMessage】失败！错误信息: $($_.Exception.Message)"
				}
			}
		}
		catch
		{
			Write-Error -Message "在处理链接创建时发生意外错误: $($_.Exception.Message)"
		}
	}

	end
	{
		Write-Verbose 'Set-ObjectLink 函数执行完毕。'
	}
}


function local:Set-OutputEncoding
{
	[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Default', ConfirmImpact = 'Low')]
	[OutputType([System.Text.Encoding])]
	param(
		[Parameter(ParameterSetName = 'Default', Position = 0, ValueFromPipeline, HelpMessage = '要设置的编码。可以是代码页（如936, 65001）或名称（如GBK, UTF8）。')]
		[ValidateSet('936', '65001', 'GBK', 'UTF8', 'Default')]
		[String]$Encoding = 'UTF8'
	)

	begin
	{
	}

	process
	{
		try
		{
			Write-Verbose "正在根据输入 '$Encoding' 解析目标编码..."
			$TargetEncoding = switch ($Encoding)
			{
				'936'
				{
					[System.Text.Encoding]::GetEncoding(936)
				}
				'GBK'
				{
					[System.Text.Encoding]::GetEncoding('GBK')
				}
				'65001'
				{
					[System.Text.Encoding]::UTF8
				}
				'UTF8'
				{
					[System.Text.Encoding]::UTF8
				}
				default
				{
					[System.Text.Encoding]::UTF8
				}
			}
			Write-Verbose "目标编码已解析为: $($TargetEncoding.EncodingName)"

			$targetResource = '当前 PowerShell 控制台的输出编码'
			$actionMessage = "将其设置为 '$($TargetEncoding.EncodingName)' (代码页: $($TargetEncoding.CodePage))"

			if ($pscmdlet.ShouldProcess($targetResource, $actionMessage))
			{
				[System.Console]::OutputEncoding = $TargetEncoding

				Write-Host '成功将控制台输出编码设置为' -NoNewline
				Write-Host " $($TargetEncoding.EncodingName) " -BackgroundColor Green -ForegroundColor Black -NoNewline
				Write-Host '。'

				return $TargetEncoding
			}
		}
		catch
		{
			Write-Error -Message "设置编码时发生错误: $($_.Exception.Message)"
		}
	}

	end
	{
		Write-Verbose '函数 Set-OutputEncoding 执行完毕。'
	}
}


function local:Compress-VideoNvenc
{
	[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Default')]
	param(
		[Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = '要压缩的视频文件路径。')]
		[Alias('From', 'InputFile')]
		[ValidateScript({ Test-Path $_ -PathType Leaf })]
		[string]$Path,

		[Parameter(Mandatory = $false, ParameterSetName = 'NewName', HelpMessage = '压缩后新文件的名称。')]
		[Alias('To', 'NewName')]
		[string]$Name,

		[Parameter(Mandatory = $false, ParameterSetName = 'Overwrite', HelpMessage = '压缩后覆盖原始文件。')]
		[switch]$Overwrite,

		[Parameter(Mandatory = $false, ParameterSetName = 'FullPath', HelpMessage = '压缩后输出文件的完整路径。')]
		[Alias('Output')]
		[string]$OutputPath,

		[Parameter(Mandatory = $false, HelpMessage = '将视频缩放到 1080p。')]
		[Alias('ST1k')]
		[switch]$ScaleTo1080p,

		[Parameter(Mandatory = $false, HelpMessage = '选择视频编码格式。')]
		[ValidateSet('h265', 'h264')]
		[string]$Codec = 'h265',

		[Parameter(Mandatory = $false, HelpMessage = '选择预设质量。')]
		[ValidateSet('p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7')]
		[string]$Preset = 'p5',

		[Parameter(Mandatory = $false, HelpMessage = '设置视频压缩质量。')]
		[ValidateRange(0, 51)]
		[int]$CQ = 24,

		[Parameter(Mandatory = $false, HelpMessage = '压缩音频。')]
		[switch]$CompressAudio
	)

	begin
	{
		if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue))
		{
			throw '错误: 未找到 ffmpeg.exe。请确保它已安装并已添加到系统的 PATH 环境变量中。'
		}
		if (-not (Get-Command ffprobe -ErrorAction SilentlyContinue))
		{
			throw '错误: 未找到 ffprobe.exe。它通常和 ffmpeg 一起提供，请确保也已添加到 PATH。'
		}
	}

	process
	{
		$FileInfo = Get-Item -Path $Path
		$Directory = $FileInfo.DirectoryName
		$BaseName = $FileInfo.BaseName
		$Extension = $FileInfo.Extension

		$TempOutputPath = Join-Path -Path $Directory -ChildPath "$($BaseName).temp$($Extension)"
		$FinalOutputPath = ''
		$ActionMessage = ''
		$IsOverwriteMode = $false

		switch ($PSCmdlet.ParameterSetName)
		{
			'Overwrite'
			{
				$IsOverwriteMode = $true
				$FinalOutputPath = $Path
				$ActionMessage = "压缩并覆盖原始文件 `"$($FileInfo.Name)`""
			}
			'FullPath'
			{
				$FinalOutputPath = $OutputPath
				$ActionMessage = "压缩文件 `"$($FileInfo.Name)`" 到指定路径 `"$FinalOutputPath`""
			}
			'NewName'
			{
				$FinalOutputPath = Join-Path -Path $Directory -ChildPath "$Name$Extension"
				if ($FinalOutputPath -eq $Path)
				{
					throw "错误: 指定的新文件名 '$Name' 与原始文件名相同。如果要覆盖，请使用 -Overwrite 参数。"
				}
				$ActionMessage = "压缩文件 `"$($FileInfo.Name)`" 并重命名为 `"$($FinalOutputPath)`""
			}
			default
			{
				$FinalOutputPath = Join-Path -Path $Directory -ChildPath "$($BaseName)_${Codec}_cq${CQ}$Extension"
				$ActionMessage = "压缩文件 `"$($FileInfo.Name)`" 到自动生成的 `"$FinalOutputPath`""
			}
		}

		$HwaccelArgs = @()
		$VideoFilter = ''

		if ($ScaleTo1080p.IsPresent)
		{
			try
			{
				$SourceHeight = ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=s=x:p=0 -i "$Path"
				if ([int]$SourceHeight -gt 1080)
				{
					$VideoFilter = 'scale_cuda=w=-2:h=1080'
					$HwaccelArgs = @('-hwaccel', 'cuda', '-hwaccel_output_format', 'cuda')
					$ActionMessage += ' (将使用 GPU 全程加速缩放至 1080p)'
				}
				else
				{
					Write-Verbose "视频原始高度为 $($SourceHeight)p，不高于 1080p，因此无需缩放。"
				}
			}
			catch
			{
				Write-Warning "无法获取视频分辨率，将不进行缩放。错误: $_"
			}
		}

		$FfmpegOutputTarget = $(if ($IsOverwriteMode)
			{
				$TempOutputPath
			}
			else
			{
				$FinalOutputPath
			}
		)

		$VideoEncoder = $(switch ($Codec)
			{
				'h265'
				{
					'hevc_nvenc'
				}
				'h264'
				{
					'h264_nvenc'
				}
			}
		)

		$Arguments = $HwaccelArgs
		$Arguments += '-i', "`"$Path`""

		if (-not [string]::IsNullOrEmpty($VideoFilter))
		{
			$Arguments += '-vf', $VideoFilter
		}

		$Arguments += '-c:v', $VideoEncoder, '-preset', $Preset, '-cq', $CQ

		if ($CompressAudio.IsPresent)
		{
			$Arguments += '-c:a', 'aac', '-b:a', '192k'
		}
		else
		{
			$Arguments += '-c:a', 'copy'
		}

		$Arguments += '-y', "`"$FfmpegOutputTarget`""

		if ($pscmdlet.ShouldProcess($Path, $ActionMessage))
		{
			Write-Host "执行命令: ffmpeg $($Arguments -join ' ')" -ForegroundColor Cyan
			$Process = Start-Process -FilePath ffmpeg -ArgumentList $Arguments -NoNewWindow -PassThru -Wait

			if ($Process.ExitCode -eq 0)
			{
				if ($IsOverwriteMode)
				{
					try
					{
						Move-Item -Path $TempOutputPath -Destination $Path -Force -ErrorAction Stop
						Write-Host '成功！原始文件已安全覆盖。' -ForegroundColor Green
					}
					catch
					{
						Write-Error "FFmpeg 压缩成功，但替换原始文件时失败: $_"
					}
				}
				else
				{
					Write-Host "视频压缩成功! 输出文件位于: $FinalOutputPath" -ForegroundColor Green
				}
			}
			else
			{
				Write-Error "ffmpeg 执行失败，退出代码: $($Process.ExitCode)。"
				if (Test-Path $TempOutputPath)
				{
					Remove-Item $TempOutputPath -Force
				}
			}
		}
	}
}


function local:Start-BCompare
{
	[CmdletBinding(DefaultParameterSetName = 'Default')]
	param(
		[Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName, HelpMessage = '要比较的左侧文件路径。')]
		[Alias('Left', 'File1')]
		[ValidateScript({ Test-Path $_ -PathType Leaf })]
		[string]$LeftPath,

		[Parameter(Mandatory, Position = 1, ValueFromPipelineByPropertyName, HelpMessage = '要比较的右侧文件路径。')]
		[Alias('Right', 'File2')]
		[ValidateScript({ Test-Path $_ -PathType Leaf })]
		[string]$RightPath
	)

	$BcompareFullPath = 'D:\Program Files (local)\BCompare\BCompare.exe'

	if (-not (Get-Command $BcompareFullPath -ErrorAction SilentlyContinue))
	{
		throw "错误: 未找到 '$BcompareFullPath'"
	}


	Start-Process -FilePath $BcompareFullPath -ArgumentList "`"$LeftPath`" `"$RightPath`"" -NoNewWindow
}


@{
	'find'   = 'Get-ObjectDetails'
	'mklink' = 'Set-ObjectLink'
	'af'     = 'Add-CppFormatFile'
	'chcp'   = 'Set-OutputEncoding'
	'cvn'    = 'Compress-VideoNvenc'
	'bcd'    = 'Backup-CloudDrive'
}.GetEnumerator() | ForEach-Object {
	$null = New-Item Alias:$($_.Key) -Value $_.Value -Force
}


function local:Get-FullChildItem
{
	Get-ChildItem -Force
}
