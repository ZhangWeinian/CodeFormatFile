using namespace System.Management.Automation
using namespace System.Management.Automation.Language


function local:Copy-SSHId
{
	[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Default')]
	param(
		[Parameter(Mandatory, Position = 0, ValueFromPipeline, ParameterSetName = 'Default')]
		[Parameter(Mandatory, Position = 0, ValueFromPipeline, ParameterSetName = 'WithIdentityFile')]
		[string]$RemoteHost,

		[Parameter(Position = 1, ParameterSetName = 'WithIdentityFile')]
		[Alias('i')]
		[string]$IdentityFile
	)

	process
	{
		$PublicKeyPath = ''
		if ($PSCmdlet.ParameterSetName -eq 'WithIdentityFile')
		{
			if (-not ($IdentityFile.EndsWith('.pub')))
			{
				$IdentityFile += '.pub'
			}
			$PublicKeyPath = $IdentityFile
		}
		else
		{
			$SSHDir = "$($env:USERPROFILE)\.ssh"
			$PreferredKeys = @(
				"$($SSHDir)\id_ed25519.pub",
				"$($SSHDir)\id_ecdsa.pub",
				"$($SSHDir)\id_rsa.pub",
				"$($SSHDir)\id_dsa.pub"
			)

			foreach ($Key in $PreferredKeys)
			{
				if (Test-Path $Key)
				{
					$PublicKeyPath = $Key
					Write-Verbose "自动检测到的公钥：$($PublicKeyPath)"
					break
				}
			}
		}

		if (-not (Test-Path $PublicKeyPath))
		{
			Write-Error "未找到公钥文件。搜索的默认密钥或指定路径 '$($PublicKeyPath)' 无效。"
			return
		}
		$PublicKeyString = (Get-Content -Path $PublicKeyPath -Raw).Trim()

		$SSHOptions = ''
		$User, $HostName = '', ''

		if ($RemoteHost -match '^(?:([^@]+)@)?([^:\s]+)(?::(\d+))?$')
		{
			$User = $matches[1]
			$HostName = $matches[2]
			if ($matches[3])
			{
				$SSHOptions = "-p $($matches[3])"
			}
		}
		else
		{
			Write-Error "无法解析远程主机字符串: '$($RemoteHost)'。请使用格式 'user@host' 或 'host'。"
			return
		}

		if (-not $User)
		{
			$User = $env:USERNAME
			Write-Warning "未指定用户。使用当前用户: '$($User)'。"
		}

		$SSHTarget = "$($User)@$($HostName)"

		$EscapedPublicKey = $PublicKeyString -replace '"', '\"'
		$RemoteCommand = @"
        GPG_PUBKEY="$($EscapedPublicKey)";
        mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys;
        if grep -q -F "\$GPG_PUBKEY" ~/.ssh/authorized_keys; then
            echo 'INFO: Key already exists on remote. No changes made.';
        else
            echo "\$GPG_PUBKEY" >> ~/.ssh/authorized_keys && echo 'INFO: Key successfully added.';
        fi
"@

		Write-Verbose "用户：$($User)"
		Write-Verbose "主机：$($HostName)"
		Write-Verbose "SSH 选项：'$($SSHOptions)'"
		Write-Verbose "公钥路径：$($PublicKeyPath)"

		if ($pscmdlet.ShouldProcess($HostName, "复制用户 '$($User)' 的 SSH 公钥"))
		{
			try
			{
				Write-Host "正在尝试连接到 $($HostName) 以安装 SSH 公钥..."

				$SSHCommand = "ssh $($SSHOptions) $($SSHTarget)"

				$Output = Write-Output $RemoteCommand | & $SSHCommand

				Write-Host ''
				if ($Output -match 'Key successfully added')
				{
					Write-Host -ForegroundColor Green '成功: 密钥已添加。'
				}
				elseif ($Output -match 'Key already exists')
				{
					Write-Host -ForegroundColor Yellow '信息: 密钥已存在于远程机器上。'
				}
				else
				{
					Write-Warning '无法确认密钥安装。请检查远程输出:'
					Write-Host $Output
				}

				Write-Host ''
				Write-Host "尝试使用以下命令登录: $($SSHCommand)"

			}
			catch
			{
				Write-Error "复制 SSH ID 失败。错误: $($_)"
			}
		}
	}
}


function local:New-ItemAndEnter
{
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
	param(
		[Parameter(Mandatory, Position = 0, HelpMessage = '要创建或进入的目录的路径。')]
		[string]$Path,

		[Parameter(HelpMessage = '如果目录已存在，则强制删除该目录及其所有内容，然后重新创建。这是一个高风险操作！')]
		[switch]$Recreate
	)

	process
	{
		try
		{
			Write-Verbose "开始处理路径: '$Path'"

			$pathExists = Test-Path -Path $Path
			$isContainer = $false
			if ($pathExists)
			{
				$isContainer = (Get-Item -Path $Path).PSIsContainer
			}

			$ActionMessage = ''
			$TargetResource = Convert-Path -Path $Path -ErrorAction SilentlyContinue

			if (-not $TargetResource)
			{
				$TargetResource = $Path
			}

			if ($pathExists)
			{
				if (-not $isContainer)
				{
					Write-Error -Message "操作中止：路径 '$Path' 已存在，但它是一个文件，而不是目录。" -Category InvalidOperation
					return
				}

				if ($Recreate)
				{
					$ActionMessage = "删除并重新创建目录 '$($TargetResource)'，然后进入该目录"
				}
				else
				{
					$ActionMessage = "进入已存在的目录 '$($TargetResource)'"
				}
			}
			else
			{
				$ActionMessage = "创建新目录 '$($TargetResource)' 并进入该目录"
			}

			if ($pscmdlet.ShouldProcess($TargetResource, $ActionMessage))
			{
				if ($pathExists)
				{
					if ($Recreate)
					{
						Write-Host "正在删除旧目录 '$TargetResource'..." -ForegroundColor Yellow
						Remove-Item -Path $TargetResource -Recurse -Force

						Write-Host "正在重新创建目录 '$TargetResource'..." -ForegroundColor Green
						$null = New-Item -ItemType Directory -Path $Path -Force
					}
				}
				else
				{
					Write-Host "正在创建新目录 '$TargetResource'..." -ForegroundColor Green
					$null = New-Item -ItemType Directory -Path $Path -Force
				}

				try
				{
					Write-Verbose "正在尝试进入目录 '$TargetResource'..."
					Set-Location -Path $TargetResource
					Write-Host "已成功进入目录: $($pwd.Path)" -ForegroundColor Cyan
				}
				catch
				{
					Write-Error -Message "目录操作已完成，但无法进入 '$TargetResource'。错误信息: $($_.Exception.Message)"
				}
			}
		}
		catch
		{
			Write-Error -Message "在执行 New-ItemAndEnter 时发生意外错误: $($_.Exception.Message)"
		}
	}
}


@{
	'ssh-copy-id' = 'Copy-SSHId'
	'mkcd'        = 'New-ItemAndEnter'
}.GetEnumerator() | ForEach-Object {
	$null = New-Item Alias:$($_.Key) -Value $_.Value -Force
}
