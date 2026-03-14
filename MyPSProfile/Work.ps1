function local:Start-WebRTC
{
	Start-Process -FilePath 'D:\Program Files\webrtc-streamer-v0.8.10-dirty-Windows-AMD64-Release\bin\webrtc-streamer.exe' -ArgumentList @(
		'-H',
		'0.0.0.0:5000',
		'-o',
		'-w',
		'D:\rtsp\webrtc-streamer-v0.8.10-dirty-Windows-AMD64-Release\share\webrtc-streamer\html',
		'rtsp://127.0.0.1:554/stream'
	) -NoNewWindow -Wait
}


function local:Start-SwarmService
{
	Push-Location -Path 'D:\Program Files\SwarmService'

	Start-Process -FilePath 'D:\Program Files\SwarmService\SwarmService.exe' -NoNewWindow -Wait

	Pop-Location
}


function local:Start-WinSCP
{
	Start-Process -FilePath 'D:\Program Files (x86)\WinSCP\WinSCP.exe' -ArgumentList 'winscp-sftp://root:orangepi;fingerprint=ssh-ed25519-thn3LhLOTSBeXg0NBaXFAcO_L0BGG8DKxmHlSlKrtpU@192.168.1.120/root/'
}


function local:New-LicenseFromFingerprint
{
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'Default')]
	[OutputType([string], [void])]
	param(
		[Parameter(Mandatory, Position = 0, HelpMessage = '从用户设备导出的 device.fp 文件路径')]
		[ValidateScript({ Test-Path -Path $_ -PathType Leaf -ErrorAction Stop })]
		[Alias('Path', 'FP')]
		[string]$FingerprintPath,

		[Parameter(Mandatory, Position = 1, HelpMessage = '许可证结束日期，格式 "yyyyMMdd"')]
		[ValidatePattern('^\d{4}\d{2}\d{2}$')]
		[Alias('ToDate', 'To', 'T')]
		[string]$EndDate,

		[Parameter(HelpMessage = '生成的 license.lic 文件的输出目录')]
		[ValidateScript({ Test-Path -Path $_ -PathType Container -ErrorAction Stop })]
		[Alias('Out')]
		[string]$OutputPath = [Environment]::GetFolderPath('Desktop'),

		[Parameter(HelpMessage = '如果指定，则不创建 license.lic 文件，而是直接在屏幕上输出许可证内容。')]
		[switch]$NoFile
	)

	function private:Get-Signature([string]$Message, [byte[]]$KeyBytes)
	{
		$hmac = New-Object System.Security.Cryptography.HMACSHA256
		$hmac.Key = $KeyBytes
		$messageBytes = [System.Text.Encoding]::UTF8.GetBytes($Message)
		$hash = $hmac.ComputeHash($messageBytes)
		$signature = ($hash | ForEach-Object { $_.ToString('x2') }) -join ''
		$hmac.Dispose()
		return $signature
	}

	function private:Protect-Text([string]$PlainText, [byte[]]$KeyBytes)
	{
		$dataBytes = [System.Text.Encoding]::UTF8.GetBytes($PlainText)
		for ($i = 0; $i -lt $dataBytes.Length; $i++)
		{
			$dataBytes[$i] = $dataBytes[$i] -bxor $keyBytes[$i % $keyBytes.Length]
		}
		return [System.Convert]::ToBase64String($dataBytes)
	}

	try
	{
		Write-Verbose '正在派生设备专属密钥...'
		$utf8NoBOM = New-Object System.Text.UTF8Encoding($false)
		$fileContent = Get-Content -Path $FingerprintPath -Raw
		$finalContent = $fileContent.Trim()

		$paddedBytes = [System.Convert]::FromBase64String($finalContent)
		$paddedString = $utf8NoBOM.GetString($paddedBytes)

		$prefixLength = 128
		$suffixLength = 128
		$corePayload = $paddedString.Substring($prefixLength, $paddedString.Length - $prefixLength - $suffixLength)

		$fingerprintBytes = [System.Convert]::FromBase64String($corePayload)
		$rawFingerprint = $utf8NoBOM.GetString($fingerprintBytes)

		$sha256 = [System.Security.Cryptography.SHA256]::Create()
		$fingerprintUtf8Bytes = $utf8NoBOM.GetBytes($rawFingerprint)
		$keyBytes = $sha256.ComputeHash($fingerprintUtf8Bytes)
		$sha256.Dispose()
		Write-Verbose "成功为设备 '$($rawFingerprint)' 派生出 HMAC 密钥。"

		Write-Verbose '正在生成许可证内容...'
		$startDate = $(Get-Date -Format 'yyyyMMdd')
		$startDateObj = [datetime]::ParseExact($startDate, 'yyyyMMdd', $null)
		$endDateObj = [datetime]::ParseExact($EndDate, 'yyyyMMdd', $null)

		if ($startDateObj -ge $endDateObj)
		{
			throw "逻辑错误：指定的结束日期 ('$($EndDate)') 必须晚于今天 ('$($startDate)')。"
		}

		$utc8Offset = [System.TimeSpan]::FromHours(8)
		$startDateTimeOffset = [System.DateTimeOffset]::new($startDateObj, $utc8Offset)
		$endDateTimeOffset = [System.DateTimeOffset]::new($endDateObj.AddDays(1), $utc8Offset)
		$startTime = $startDateTimeOffset.ToUnixTimeMilliseconds()
		$endTime = $endDateTimeOffset.ToUnixTimeMilliseconds() - 1

		$messageToSign = "$($startTime)|$($endTime)"
		$signature = Get-Signature -Message $messageToSign -KeyBytes $keyBytes
		$plainText = "$($messageToSign)|$($signature)"
		$encryptedContent = Protect-Text -PlainText $plainText -KeyBytes $keyBytes
		Write-Verbose '成功生成加密的许可证内容。'

		if ($NoFile)
		{
			Write-Host "为设备 '$($rawFingerprint.Split(':')[1])' 生成的许可证内容:" -ForegroundColor White
			Write-Host $encryptedContent -ForegroundColor Green
		}
		else
		{
			$licenseFilePath = Join-Path -Path $OutputPath -ChildPath 'license.lic'
			$processTarget = "文件 '$($licenseFilePath)'"
			$processAction = "创建/覆盖许可证 (有效期至 $($EndDate))"

			if ((Test-Path -Path $licenseFilePath) -and -not $PSCmdlet.ShouldContinue($processAction, "目标 '$($processTarget)' 已存在。您确定要继续吗?"))
			{
				Write-Warning '操作已由用户取消。'
				return
			}

			if ($PSCmdlet.ShouldProcess($processTarget, $processAction))
			{
				Set-Content -Path $licenseFilePath -Value $encryptedContent -Force -Encoding $utf8NoBOM
				Write-Host '许可证已成功保存到: ' -NoNewline
				Write-Host "'$($licenseFilePath)'" -ForegroundColor Green
			}
		}
	}
	catch
	{
		Write-Error "生成许可证时出错: $($_.Exception.Message)"
	}
}


function local:Test-LicenseFromFingerprint
{
	[CmdletBinding(DefaultParameterSetName = 'Default')]
	[OutputType([PSCustomObject])]
	param(
		[Parameter(Mandatory, Position = 0, HelpMessage = '要验证的 license.lic 文件路径')]
		[ValidateScript({ Test-Path -Path $_ -PathType Leaf -ErrorAction Stop })]
		[Alias('LPath', 'LP')]
		[string]$LicensePath,

		[Parameter(Mandatory, Position = 1, HelpMessage = '生成该许可证所用的 device.fp 文件路径')]
		[ValidateScript({ Test-Path -Path $_ -PathType Leaf -ErrorAction Stop })]
		[Alias('FPath', 'FP')]
		[string]$FingerprintPath
	)

	function private:Get-Signature([string]$Message, [byte[]]$KeyBytes)
	{
		$hmac = New-Object System.Security.Cryptography.HMACSHA256
		$hmac.Key = $KeyBytes
		$messageBytes = [System.Text.Encoding]::UTF8.GetBytes($Message)
		$hash = $hmac.ComputeHash($messageBytes)
		$signature = ($hash | ForEach-Object { $_.ToString('x2') }) -join ''
		$hmac.Dispose()
		return $signature
	}

	function private:Convert-Text([string]$DisguisedText, [byte[]]$KeyBytes)
	{
		try
		{
			$dataBytes = [System.Convert]::FromBase64String($DisguisedText)
			for ($i = 0; $i -lt $dataBytes.Length; $i++)
			{
				$dataBytes[$i] = $dataBytes[$i] -bxor $keyBytes[$i % $keyBytes.Length]
			}
			$utf8NoBOM = New-Object System.Text.UTF8Encoding($false)
			return $utf8NoBOM.GetString($dataBytes)
		}
		catch
		{
			return $null
		}
	}

	try
	{
		Write-Verbose "正在从 '$($FingerprintPath)' 派生验证密钥..."
		$utf8NoBOM = New-Object System.Text.UTF8Encoding($false)
		$fileContent = Get-Content -Path $FingerprintPath -Raw
		$finalContent = $fileContent.Trim()

		$paddedBytes = [System.Convert]::FromBase64String($finalContent)
		$paddedString = $utf8NoBOM.GetString($paddedBytes)

		$prefixLength = 128
		$suffixLength = 128
		$corePayload = $paddedString.Substring($prefixLength, $paddedString.Length - $prefixLength - $suffixLength)

		$fingerprintBytes = [System.Convert]::FromBase64String($corePayload)
		$rawFingerprint = $utf8NoBOM.GetString($fingerprintBytes)

		$sha256 = [System.Security.Cryptography.SHA256]::Create()
		$fingerprintUtf8Bytes = $utf8NoBOM.GetBytes($rawFingerprint)
		$keyBytes = $sha256.ComputeHash($fingerprintUtf8Bytes)
		$sha256.Dispose()
		Write-Verbose "成功为设备 '$($rawFingerprint)' 派生出验证密钥。"

		Write-Verbose "正在读取并验证许可证文件 '$($LicensePath)'..."
		$licenseData = (Get-Content -Path $LicensePath -Raw).Trim()

		if ([string]::IsNullOrWhiteSpace($licenseData))
		{
			throw "未能加载有效的许可证内容，文件 '$($LicensePath)' 可能为空。"
		}

		$plainText = Convert-Text -DisguisedText $licenseData -KeyBytes $keyBytes
		if (-not $plainText)
		{
			throw "解析失败：无法解密内容，请检查密钥 ($($FingerprintPath)) 或许可证内容是否正确。"
		}

		$parts = $plainText.Split('|')
		if ($parts.Count -ne 3)
		{
			throw '解析失败：许可证内容格式不正确，应包含三个部分。'
		}

		try
		{
			$extractedStartTime = [long]$parts[0]
			$extractedEndDate = [long]$parts[1]
		}
		catch
		{
			throw '解析失败：许可证内容中的时间戳格式无效。'
		}

		$extractedSignature = $parts[2]
		$recalculatedSignature = Get-Signature -Message "$($extractedStartTime)|$($extractedEndDate)" -KeyBytes $keyBytes
		$isSignatureValid = $null -eq (Compare-Object -ReferenceObject $extractedSignature -DifferenceObject $recalculatedSignature -CaseSensitive -SyncWindow 0)

		$baseDate = Get-Date '1970-01-01 00:00:00Z'
		$startDateObject = $baseDate.AddMilliseconds($extractedStartTime)
		$endDateObject = $baseDate.AddMilliseconds($extractedEndDate)

		$utc8Offset = [System.TimeSpan]::FromHours(8)
		$nowInUtc8 = [System.DateTimeOffset]::UtcNow.ToOffset($utc8Offset)
		$todayInUtc8 = $nowInUtc8.Date
		$startDateInUtc8 = ([System.DateTimeOffset]$startDateObject).ToOffset($utc8Offset).Date
		$licenseStatus = $(if ($isSignatureValid)
			{
				if ($nowInUtc8 -gt $endDateObject)
				{
					'已过期'
				}
				elseif ($todayInUtc8 -lt $startDateInUtc8)
				{
					'尚未生效'
				}

				else
				{
					'有效'
				}
			}
			else
			{
				'签名无效'
			}
		)

		[PSCustomObject]@{
			许可证状态 = $licenseStatus
			设备指纹  = $rawFingerprint
			签名有效性 = $isSignatureValid
			开始日期  = ([System.DateTimeOffset]$startDateObject).ToOffset($utc8Offset).ToString('yyyy-MM-dd HH:mm:ss "UTC+8"')
			结束日期  = ([System.DateTimeOffset]$endDateObject).ToOffset($utc8Offset).ToString('yyyy-MM-dd HH:mm:ss "UTC+8"')
		}
	}
	catch
	{
		Write-Error "验证许可证时出错: $($_.Exception.Message)"
	}
}


function Start-SwarmCatalog
{
	[CmdletBinding(DefaultParameterSetName = 'Default')]
	param(
		[Parameter(Position = 0, HelpMessage = 'java.exe 的完整路径')]
		[ValidateScript({ Test-Path -Path $_ -PathType Leaf -ErrorAction Stop })]
		[Alias('Java')]
		[string]$JavaPath = 'D:\Users\ZhangWeinian\.jdks\ms-11.0.27\bin\java.exe',

		[Parameter(Position = 1, HelpMessage = 'jar 文件的完整路径')]
		[ValidateScript({ Test-Path -Path $_ -PathType Leaf -ErrorAction Stop })]
		[Alias('Jar')]
		[string]$JarPath = 'D:\Program Files\SwarmCatalog\SwarmCatalog.jar'
	)

	try
	{
		$InstallPath = Split-Path -Path $JarPath -Parent

		if (-not (Test-Path $JavaPath -PathType Leaf))
		{
			throw "找不到 Java 可执行文件: `"$JavaPath`"。"
		}
		if (-not (Test-Path $JarPath -PathType Leaf))
		{
			throw "找不到 JAR 文件: `"$JarPath`"。"
		}

		$javaArgs = @(
			'-Xmx1024m',
			'-jar',
			$JarPath
		)

		Write-Host '正在准备后台任务以打开浏览器（8 秒后）...' -ForegroundColor Cyan
		$jobScriptBlock = {
			Start-Sleep -Seconds 8
			Start-Process -FilePath 'http://localhost:30906/swagger-ui.html'
			Start-Process -FilePath 'http://localhost:30906/'
		}

		Write-Verbose '正在启动后台任务以打开浏览器...'
		$null = Start-Job -ScriptBlock $jobScriptBlock

		try
		{
			Write-Verbose "正在保存当前工作目录...（$($InstallPath)）"
			Push-Location -Path $InstallPath
			Write-Host '正在前台启动 SwarmCatalog 服务... (按 Ctrl+C 停止)' -ForegroundColor Green
			& $JavaPath @javaArgs
		}
		finally
		{
			Write-Verbose '正在恢复原始工作目录。'
			Pop-Location
		}
	}
	catch
	{
		Write-Error "启动 SwarmCatalog 服务时出错: $($_.Exception.Message)"
	}
}


@{
	'emqx'     = 'D:\Program Files\emqx_v5\bin\emqx.cmd'
	'emqx3'    = 'D:\Program Files\emqx_v3\bin\emqx.cmd'
	'webrtc'   = 'Start-WebRTC'
	'ss'       = 'Start-SwarmService'
	'ws'       = 'Start-WinSCP'
	'new-li'   = 'New-LicenseFromFingerprint'
	'li-check' = 'Test-LicenseFromFingerprint'
	'ssc'      = 'Start-SwarmCatalog'
}.GetEnumerator() | ForEach-Object {
	$null = New-Item Alias:$($_.Key) -Value $($_.Value) -Force
}
