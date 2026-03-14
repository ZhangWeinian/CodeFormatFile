using namespace System.Management.Automation
using namespace System.Management.Automation.Language


Set-PSReadLineKeyHandler -Chord '(', '[', '{', '"', "'" -ScriptBlock {
	param($Key, $Arg)

	$Open = [string]$Key.KeyChar
	$Close = @{ '(' = ')'; '[' = ']'; '{' = '}'; '"' = '"'; "'" = "'" }[$Open]

	$SelectionStart = $null
	$SelectionLength = $null
	[Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$SelectionStart, [ref]$SelectionLength)

	$Line = $null
	$Cursor = $null
	[Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$Line, [ref]$Cursor)

	if ($SelectionStart -ne -1)
	{
		$Selected = $Line.SubString($SelectionStart, $SelectionLength)
		[Microsoft.PowerShell.PSConsoleReadLine]::Replace($SelectionStart, $SelectionLength, "${Open}${Selected}${Close}")
		[Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($SelectionStart + $SelectionLength + 2)
	}
	else
	{
		if (($Open -eq $Close) -and ($Cursor -lt $Line.Length) -and ([string]$Line[$Cursor] -eq $Close))
		{
			[Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($Cursor + 1)
		}
		else
		{
			[Microsoft.PowerShell.PSConsoleReadLine]::Insert("${Open}${Close}")
			[Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($Cursor + 1)
		}
	}
} -BriefDescription '自动补全括号和引号'


Set-PSReadLineKeyHandler -Chord ')', ']', '}' -ScriptBlock {
	param($Key, $Arg)
	$Close = $Key.KeyChar
	$Line = $null
	$Cursor = $null
	[Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$Line, [ref]$Cursor)

	if (($Cursor -lt $Line.Length) -and ($Line[$Cursor] -eq $Close))
	{
		[Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($Cursor + 1)
	}
	else
	{
		[Microsoft.PowerShell.PSConsoleReadLine]::Insert($Close)
	}
} -BriefDescription '跳过或插入关闭括号'


Set-PSReadLineKeyHandler -Key 'Backspace' -ScriptBlock {
	param($Key, $Arg)

	$Line = $null
	$Cursor = $null
	[Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$Line, [ref]$Cursor)

	if ($Cursor -gt 0)
	{
		$ToMatch = $null
		$CloseBraceWithSpace = $false
		if ($Cursor -lt $Line.Length)
		{
			switch ($Line[$Cursor])
			{
				<#case#> '"'
				{
					$ToMatch = '"'; break
				}
				<#case#> "'"
				{
					$ToMatch = "'"; break
				}
				<#case#> ')'
				{
					$ToMatch = '('; break
				}
				<#case#> ']'
				{
					$ToMatch = '['; break
				}
				<#case#> '}'
				{
					$ToMatch = '{'; break
				}
				<#case#> ' '
				{
					if ((($Cursor + 1) -lt $Line.Length) -and ($Line[$Cursor + 1] -eq '}'))
					{
						$ToMatch = '{'
						$CloseBraceWithSpace = $true
					}
					break
				}
			}
		}

		if (($null -ne $ToMatch) -and ($Line[$Cursor - 1] -eq $ToMatch))
		{
			if ($CloseBraceWithSpace)
			{
				[Microsoft.PowerShell.PSConsoleReadLine]::Delete($Cursor - 1, 3)
			}
			else
			{
				[Microsoft.PowerShell.PSConsoleReadLine]::Delete($Cursor - 1, 2)
			}
		}
		else
		{
			[Microsoft.PowerShell.PSConsoleReadLine]::BackwardDeleteChar($Key, $Arg)
		}
	}
} -BriefDescription '自动删除成对的括号'


Set-PSReadLineKeyHandler -Key 'Alt+w' -ScriptBlock {
	param($Key, $Arg)

	$Line = $null
	$Cursor = $null
	[Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$Line, [ref]$Cursor)
	[Microsoft.PowerShell.PSConsoleReadLine]::AddToHistory($Line)
	[Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
} -BriefDescription '添加到历史记录'


Set-PSReadLineKeyHandler -Key 'Ctrl+0' -ScriptBlock {
	param($Key, $Arg)

	$SelectionStart = $null
	$SelectionLength = $null
	[Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$SelectionStart, [ref]$SelectionLength)

	$Line = $null
	$Cursor = $null
	[Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$Line, [ref]$Cursor)

	if ($SelectionStart -ne -1)
	{
		[Microsoft.PowerShell.PSConsoleReadLine]::Replace(
			$SelectionStart, $SelectionLength,
			$('$(', $Line.SubString($SelectionStart, $SelectionLength), ')' -join ''))
		[Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($SelectionStart + $SelectionLength + 3)
	}
	else
	{
		[Microsoft.PowerShell.PSConsoleReadLine]::Insert('$()')
		[Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($Cursor + 2)
	}
} -BriefDescription '添加预运行括号'


Set-PSReadLineKeyHandler -Key 'Ctrl+5' -ScriptBlock {
	param($Key, $Arg)

	$Line = $null
	$Cursor = $null
	[Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$Line, [ref]$Cursor)

	[Microsoft.PowerShell.PSConsoleReadLine]::Insert(' | %{  }')
	[Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($Cursor + 6)
} -BriefDescription '添加管道中的 ForEach-Object 模板'


Set-PSReadLineKeyHandler -Key 'Ctrl+/' -ScriptBlock {
	param($Key, $Arg)

	$Line = $null
	$Cursor = $null
	[Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$Line, [ref]$Cursor)

	[Microsoft.PowerShell.PSConsoleReadLine]::Insert(' | ?{  }')
	[Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($Cursor + 6)
} -BriefDescription '添加管道中的 Where-Object 模板'


Set-PSReadLineKeyHandler -Key 'Ctrl+\' -ScriptBlock {
	param($Key, $Arg)

	$Line = $null
	$Cursor = $null
	[Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$Line, [ref]$Cursor)

	[Microsoft.PowerShell.PSConsoleReadLine]::Insert(' | ')
	[Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($Cursor + 3)
} -BriefDescription '添加管道符号'


Set-PSReadLineKeyHandler -Key 'Ctrl+-' -ScriptBlock {
	param($Key, $Arg)

	$Line = $null
	$Cursor = $null
	[Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$Line, [ref]$Cursor)

	[Microsoft.PowerShell.PSConsoleReadLine]::Insert('$_')
	[Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($Cursor + 2)
} -BriefDescription '添加 $_ 变量'


Set-PSReadLineKeyHandler -Key 'F7' -ScriptBlock {
	$HistoryPath = (Get-PSReadLineOption).HistorySavePath

	if ((-not ([string]::IsNullOrWhiteSpace($HistoryPath))) -and (Test-Path $HistoryPath))
	{
		$Pattern = $null
		[Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$Pattern, [ref]$null)
		if ($Pattern)
		{
			$Pattern = [regex]::Escape($Pattern)
		}

		$History = [System.Collections.ArrayList]@(
			$Last = ''
			$Lines = ''
			foreach ($Line in [System.IO.File]::ReadLines($HistoryPath))
			{
				if ($Line.EndsWith('`'))
				{
					$Line = $Line.Substring(0, $Line.Length - 1)
					$Lines = if ($Lines)
					{
						"$Lines`n$Line"
					}
					else
					{
						$Line
					}
					continue
				}

				if ($Lines)
				{
					$Line = "$Lines`n$Line"
					$Lines = ''
				}

				if (($Line -cne $Last) -and (!$Pattern -or ($Line -match $Pattern)))
				{
					$Last = $Line
					$Line
				}
			}
		)
		$History.Reverse()

		$Command = $History | Out-GridView -Title History -PassThru
		if ($Command)
		{
			[Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
			[Microsoft.PowerShell.PSConsoleReadLine]::Insert(($Command -join "`n"))
		}
	}
	else
	{
		[Microsoft.PowerShell.PSConsoleReadLine]::Ding()
	}
} -BriefDescription '显示历史记录对话框'


Set-PSReadLineKeyHandler -Key 'Alt+s' -ScriptBlock {
	param($Key, $Arg)

	$Ast = $null
	$Tokens = $null
	$Errors = $null
	$Cursor = $null
	[Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$Ast, [ref]$Tokens, [ref]$Errors, [ref]$Cursor)

	$StartAdjustment = 0
	foreach ($Token in $Tokens)
	{
		if ($Token.TokenFlags -band [TokenFlags]::CommandName)
		{
			$Alias = $ExecutionContext.InvokeCommand.GetCommand($Token.Extent.Text, 'Alias')
			if ($Alias -ne $null)
			{
				$ResolvedCommand = $Alias.ResolvedCommandName
				if ($ResolvedCommand -ne $null)
				{
					$Extent = $Token.Extent
					$Length = $Extent.EndOffset - $Extent.StartOffset
					[Microsoft.PowerShell.PSConsoleReadLine]::Replace(
						$Extent.StartOffset + $StartAdjustment,
						$Length,
						$ResolvedCommand)

					$StartAdjustment += ($ResolvedCommand.Length - $Length)
				}
			}
		}
	}
} -BriefDescription '替换命令别名为实际命令'


Set-PSReadLineKeyHandler -Key 'Ctrl+V' -ScriptBlock {
	param($Key, $Arg)

	Add-Type -Assembly PresentationCore
	if ([System.Windows.Clipboard]::ContainsText())
	{
		$Text = [System.Windows.Clipboard]::GetText()
		$Text = ($Text -replace "`r`n", "`n" -replace "`r", "`n" -replace "`n", "`r`n").TrimEnd()
		$Text = ($Text -split "`r`n" | ForEach-Object { $_.TrimEnd() }) -join "`r`n"
		[Microsoft.PowerShell.PSConsoleReadLine]::Insert("@'`r`n$Text`r`n'@")
	}
	else
	{
		[Microsoft.PowerShell.PSConsoleReadLine]::Ding()
	}
} -BriefDescription '将剪贴板中的文本作为 here-string 插入'


Set-PSReadLineKeyHandler -Key 'Alt+x' -ScriptBlock {
	$Buffer = $null
	$Cursor = 0
	[Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$Buffer, [ref]$Cursor)

	if ($Cursor -lt 4)
	{
		return
	}

	$Number = 0
	$IsNumber = [int]::TryParse(
		$Buffer.Substring($Cursor - 4, 4),
		[System.Globalization.NumberStyles]::AllowHexSpecifier,
		$null,
		[ref]$Number
	)

	if (-not $IsNumber)
	{
		return
	}

	try
	{
		$Unicode = [char]::ConvertFromUtf32($Number)
	}
	catch
	{
		return
	}

	[Microsoft.PowerShell.PSConsoleReadLine]::Delete($Cursor - 4, 4)
	[Microsoft.PowerShell.PSConsoleReadLine]::Insert($Unicode)
} -BriefDescription '将十六进制 Unicode 转义序列转换为字符'


Set-PSReadLineKeyHandler -Key "Alt+'" -ScriptBlock {
	param($Key, $Arg)

	$Ast = $null
	$Tokens = $null
	$Errors = $null
	$Cursor = $null
	[Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$Ast, [ref]$Tokens, [ref]$Errors, [ref]$Cursor)

	$TokenToChange = $null
	foreach ($Token in $Tokens)
	{
		$Extent = $Token.Extent
		if ($Extent.StartOffset -le $Cursor -and $Extent.EndOffset -ge $Cursor)
		{
			$TokenToChange = $Token
			if ($Extent.EndOffset -eq $Cursor -and $foreach.MoveNext())
			{
				$NextToken = $foreach.Current
				if ($NextToken.Extent.StartOffset -eq $Cursor)
				{
					$TokenToChange = $NextToken
				}
			}
			break
		}
	}

	if ($TokenToChange -ne $null)
	{
		$Extent = $TokenToChange.Extent
		$TokenText = $Extent.Text
		$Replacement = $null

		if ($TokenText.StartsWith('"') -and $TokenText.EndsWith('"'))
		{
			$Replacement = $TokenText.Substring(1, $TokenText.Length - 2)
		}
		elseif ($TokenText.StartsWith("'") -and $TokenText.EndsWith("'"))
		{
			$Replacement = '"' + $TokenText.Substring(1, $TokenText.Length - 2) + '"'
		}
		else
		{
			$Replacement = "'" + $TokenText + "'"
		}

		[Microsoft.PowerShell.PSConsoleReadLine]::Replace(
			$Extent.StartOffset,
			$TokenText.Length,
			$Replacement)
	}
} -BriefDescription '切换引号类型'


Set-PSReadLineOption -CommandValidationHandler {
	param(
		[CommandAst]$CommandAst
	)

	$RootAst = $CommandAst
	while ($RootAst.Parent)
	{
		$RootAst = $RootAst.Parent
	}

	$AllCommands = $RootAst.FindAll({
			$args[0] -is [System.Management.Automation.Language.CommandAst]
		}, $true
	)

	for ($i = $AllCommands.Count - 1; $i -ge 0; $i--)
	{
		$CurrentCommand = $AllCommands[$i]

		try
		{
			$CommandInfo = Get-Command $CurrentCommand.GetCommandName() -ErrorAction Stop
		}
		catch
		{
			continue
		}

		$UserInput = $CurrentCommand.GetCommandName()
		$StandardName = $CommandInfo.Name

		if (($UserInput -eq $StandardName) -and ($UserInput -cne $StandardName))
		{
			[Microsoft.PowerShell.PSConsoleReadLine]::Replace(
				$CurrentCommand.Extent.StartOffset,
				$UserInput.Length,
				$StandardName
			)
		}
	}
}


Set-PSReadLineKeyHandler -Chord Enter -Function ValidateAndAcceptLine
