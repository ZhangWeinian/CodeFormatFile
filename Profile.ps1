# 设置输出编码为 GBK
# [System.Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(936)


# 引入一些自定义的 PS 函数
Get-ChildItem -Path (Join-Path -Path $([System.Environment]::GetFolderPath('MyDocuments')) -ChildPath 'PowerShell\MyPSProfile\*.ps1') | ForEach-Object { . $($_.fullname) }


# 设置一些不依赖环境的自定义别名
@{
	'2f'     = 'Out-File'
	'2v'     = 'Set-Clipboard'
	'li'     = 'Get-Item'
	'll'     = 'Get-FullChildItem'
	'lip'    = 'Get-ItemProperty'
	'pp'     = 'Write-Output'
	'split'  = 'Split-Path'
	'rename' = 'Rename-Item'
}.GetEnumerator() | ForEach-Object {
	$null = New-Item Alias:$($_.Key) -Value $($_.Value) -Force
}


# 设置一些不依赖环境的全局变量
@{
	'Desktop'  = 'D:\Users\ZhangWeinian\Desktop'
	'UserFont' = 'C:\Users\ZhangWeinian\AppData\Local\Microsoft\Windows\Fonts'
	'vcpkg'    = 'D:\ProgramData\Working Projects\Projects for GitResources\vcpkg'
}.GetEnumerator() | ForEach-Object {
	if (-not (Test-Path -Path "Variable:\$($_.Key)"))
	{
		$null = New-Variable -Name $($_.Key) -Value $($_.Value) -Option ReadOnly -Scope Global
	}
}


# 设置一些 git 命令的函数
@{
	'gs'     = { git status }
	'gp'     = { git push }
	'gpl'    = { git pull }
	'gco'    = { git checkout @args }
	'gb'     = { git branch -a }
	'gc-ssh' = { param($m) git clone $($m) }
}.GetEnumerator() | ForEach-Object {
	$null = Set-Item -Path "Function:\$($_.Key)" -Value $($_.Value) -Force
}

# 设置一些只依赖 PSReadLine 的快捷键
@{
	'Tab'    = 'AcceptNextSuggestionWord'
	'Ctrl+=' = 'GotoBrace'
}.GetEnumerator() | ForEach-Object {
	Set-PSReadLineKeyHandler -Key $($_.Key) -Function $($_.Value)
}


# 设置项详细参考 https://learn.microsoft.com/zh-cn/powershell/module/psreadline/set-psreadlineoption
$script:PSReadLineOptions = [Ordered]@{
	'HistorySaveStyle'   = 'SaveNothing'
	'HistorySavePath'    = 'D:\Users\ZhangWeinian\Documents\PowerShell\PSReadline_history.txt'
	'PredictionSource'   = 'HistoryAndPlugin'
	'PromptText'         = "$([char]27)[91m( ❁´◡``❁ ) ♪$([char]27)[0m ", "$([char]27)[31m(  O.o  ) ?$([char]27)[0m "
	'ContinuationPrompt' = "$([char]27)[34m╰─ $([char]27)[91m- - - - -> ♪$([char]27)[0m "

	'Colors'             = @{
		'ContinuationPrompt'     = "$([char]27)[91m"		 # 延续提示的颜色
		'Emphasis'               = "$([char]27)[37;46m"		 # 强调颜色。例如，搜索历史记录时匹配的文本
		'Error'                  = "$([char]27)[4;31m"		 # 错误颜色。例如，在提示中
		'Selection'              = "$([char]27)[4;37;42m"	 # 突出显示菜单选择或所选文本的颜色
		'Default'                = "$([char]27)[3;30m"		 # 默认标记颜色
		'Comment'                = '#008000'				# 注释标记颜色
		'KeyWord'                = '#1100ff'				# 关键字标记颜色
		'String'                 = '#bd1b1b'				# 字符串标记颜色
		'Operator'               = '#008000'				# 运算符标记颜色
		'Variable'               = '#4f71d5'				# 变量标记颜色
		'Command'                = '#986c24'				# 命令标记颜色
		'Parameter'              = '#9400b9'				# 参数标记颜色
		'Type'                   = '#9400b9'				# 类型标记颜色
		'Number'                 = '#000000'				# 数字标记颜色
		'Member'                 = '#cd9643'				# 成员名称标记颜色
		'InlinePrediction'       = "$([char]27)[4;37;42m"	 # 预测建议内联视图的颜色
		'ListPrediction'         = '#007736'				# 前导 > 字符和预测源名称的颜色
		'ListPredictionSelected' = "$([char]27)[3;34m"		 # 列表视图中所选预测的颜色
		'ListPredictionTooltip'  = "$([char]27)[3;36m"		 # 预测列表工具提示
	}
}; Set-PSReadLineOption @script:PSReadLineOptions


function local:prompt
{
	function StrStyle
	{
		param(
			[Parameter(Position = 0, Mandatory)]
			[string]$Str,

			[Parameter(Position = 1, Mandatory)]
			[string]$Style
		)

		$StrStyleSet = @{
			'StyleEnd'              = "$([char]27)[0m"
			'ForegroundMagenta'     = "$([char]27)[35;3m"
			'ForegroundBlueBold'    = "$([char]27)[34m"
			'ForegroundBrightRed'   = "$([char]27)[91m"
			'ForegroundBrightGreen' = "$([char]27)[92m"
			'ForegroundBrightBlue'  = "$([char]27)[94m"
		}

		if ($StrStyleSet.ContainsKey($Style))
		{
			return "$($StrStyleSet[$Style])$Str$($StrStyleSet['StyleEnd'])"
		}
		else
		{
			return $Str
		}
	}

	function Get-GitInfo
	{
		return ''

		if (-not (Get-Command git -ErrorAction SilentlyContinue))
		{
			return ''
		}

		$null = & git rev-parse --is-inside-work-tree 2>$null
		if ($LASTEXITCODE -ne 0)
		{
			return ''
		}

		$Branch = & git rev-parse --abbrev-ref HEAD 2>$null
		$Status = & git status --porcelain 2>$null

		$StatusSymbol = if ([string]::IsNullOrEmpty($Status))
		{
			StrStyle '✓' ForegroundBrightGreen
		}
		else
		{
			StrStyle '●' ForegroundBrightRed
		}

		$BranchStr = StrStyle $Branch ForegroundMagenta

		return "    <Git>$($BranchStr)($($StatusSymbol))"
	}

	$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

	$HostInfo = $(StrStyle '╭─> ' ForegroundBlueBold), '<Host>', $(
		if ($IsAdmin)
		{
			StrStyle 'Admin' ForegroundBrightGreen
		}
		else
		{
			StrStyle 'User' ForegroundBrightBlue
		}
	), $(if ('Core' -eq $PSVersionTable.PSEdition)
		{
			StrStyle '@PS-Core' ForegroundMagenta
		}
		else
		{
			StrStyle '@Win-PS' ForegroundMagenta
		}
	) -join ''

	$PathInfo = '<Path>', $(
		$Path = $(Get-Location).Path

		if ($Path.Length -gt ($Host.UI.RawUI.WindowSize.Width - 82))
		{
			StrStyle "[Using Cmdlet 'pwd']" ForegroundMagenta
		}
		else
		{
			StrStyle $Path ForegroundMagenta
		}
	), $(Get-GitInfo) -join ''

	$TimeInfo = '<Time>', $(StrStyle $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ForegroundMagenta) -join ''

	return $($HostInfo, $PathInfo, $TimeInfo -join ' '), $(
		$(StrStyle '╰─> ' ForegroundBlueBold), $(StrStyle '( ❁´◡`❁ ) ♪ ' ForegroundBrightRed) -join ''
	) -join "`n"
}
