' Open Audit
' Software and Hardware Inventory
' (c) Mark Unwin 2012 
' http://www.open-audit.org
' Licensed under the AGPL v3
' http://www.fsf.org/licensing/licenses/agpl-3.0.html 


' the number of audits to run concurrently
number_of_audits = 30

' this tells the script to run the audit from this PC or 
' to copy the files to the remote pc and run the script remotely using PSexec

' NOTE - make sure if using the "remote" option that network comms are allowed 
' to be initated at the remote PC, connecting to the OAv2 host
' audit_run_type = "remote"
audit_run_type = "local"

' the below are needed for remote audits as PSexec takes them as command line arguements
' I don't think (could be wrong) that PSexec can use the local logged on users credentials
' If it can, someone please provide me with a "how to"
' NOTE - if using the "local" option, the below are not needed
remote_user = ""
remote_password = ""

' the name and path of the audit script to use
script_name = ".\audit_windows.vbs"

' set the below to your active directory domain
' you can add multiple domains in the array below.
'domain_array = array("LDAP://your.domain.here", "LDAP://domain.number.2", "LDAP://another.domain.org")
domain_array = array("LDAP://MYDOMAIN.local")


' if operating_system has a value, 
' restricts the audit to only systems with the specified operating system
' leave blank for all computers, regardless of OS

' operating_system = "Windows 2000 Professional"
' operating_system = "Windows Vista"
' operating_system = "Windows 2000 Server"
' operating_system = "Windows Server 2008"
' operating_system = "Windows Server 2003"
' operating_system = "Windows 7"
' operating_system = "Server"
' operating_system = "Windows"
operating_system = ""

' if set, create an output file of all retrieved systems from active directory
output_file = ".\audit_domain.txt"

' update with any submitted command line switches
Set objArgs = WScript.Arguments

For Each strArg in objArgs
    if instr(strArg, "=") then
		varArray = split(strArg, "=")
		select case varArray(0)

			case "operating_system"
				operating_system = varArray(1)

			case "local_domain"
				local_domain = varArray(1)

			case "script_name"
				script_name = varArray(1)

			case "number_of_audits"
				number_of_audits = varArray(1)

			case "audit_run_type"
				audit_run_type = varArray(1)

			case "remote_user"
				remote_user = varArray(1)

			case "remote_password"
				remote_password = varArray(1)

		end select
	end if
Next 

' leave the below settings
strComputer = "."
const HKEY_CLASSES_ROOT  = &H80000000
const HKEY_CURRENT_USER  = &H80000001
const HKEY_LOCAL_MACHINE = &H80000002
const HKEY_USERS         = &H80000003
const FOR_APPENDING 	 = 8
const ads_scope_subtree  = 2

set objWMIService = GetObject("winmgmts:\\" & strComputer & "\root\cimv2") 
set objWMIService2 = GetObject("winmgmts:\\" & strComputer & "\root\WMI")
set oReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & strComputer & "\root\default:StdRegProv")
set objShell = CreateObject("WScript.Shell")
set objFSO = CreateObject("Scripting.FileSystemObject")
set wshNetwork = WScript.CreateObject( "WScript.Network" )

set objlocalwmiservice = getobject("winmgmts:root\cimv2")
set colitems = objlocalwmiservice.execquery("select * from win32_process",,48)
for each objitem in colitems
	if instr (objitem.commandline, wscript.scriptname) <> 0 then
		current_pid = objitem.processid
	end if
next


if (domain_array(0) = "") and (local_domain > "") then
	domain_array(0) = local_domain
else
	if local_domain > "" then
		number_of_domains = ubound(domain_array)+1
		redim Preserve domain_array(number_of_domains)
		domain_array(number_of_domains) = local_domain
	end if
end if


for l = 0 to ubound(domain_array)
	local_domain = domain_array(l)
	wscript.echo "Now Auditing: " & local_domain
	' retrieve all computers objects from domain
	set objconnection = createobject("adodb.connection")
	set objcommand = createobject("adodb.command")
	objconnection.provider = "adsdsoobject"
	objconnection.open "active directory provider"
	set objcommand.activeconnection = objconnection
	objcommand.commandtext = "select name, location, operatingSystem, lastLogon from '" & local_domain & "' where objectclass='computer'"
	wscript.echo objcommand.commandtext
	objcommand.properties("page size") = 1000
	objcommand.properties("searchscope") = ads_scope_subtree
	objcommand.properties("sort on") = "name"
	set objrecordset = objcommand.execute
	objrecordset.movefirst
	totcomp = objrecordset.recordcount -1
	redim pc_array(totcomp) ' set array to computer count
	wscript.echo "number of systems retrieved from ldap: " & totcomp
	count = 0
	do until objrecordset.eof
		strcomputer = objrecordset.fields("name").value
		computer_os = objrecordset.fields("operatingSystem").value
		if (((len(operating_system) > 0) AND (instr(computer_os, operating_system) > 0)) OR (len(operating_system) = 0))then
			pc_array(count) = strcomputer ' feed computers into array
			count = count + 1
		end if
		objrecordset.movenext
	loop
	num_running = HowMany
	wscript.echo "number of filtered systems: " & count
	wscript.echo "--------------"
	redim Preserve pc_array(count)


	' generates a text file of retrieved PCs
	if (output_file > "") then
	for i = 0 to ubound(pc_array)
		retrieved_from_ad = retrieved_from_ad & pc_array(i) & vbcrlf
	next
	set objTS = objFSO.OpenTextFile(output_file, FOR_APPENDING, True)
	objTS.Write retrieved_from_ad
	end if

	if audit_run_type = "local" then
		for i = 0 to ubound(pc_array)
			while num_running > number_of_audits
				wscript.echo("processes running (" & num_running & ") greater than number wanted (" & number_of_audits & ")")
				wscript.echo("therefore - sleeping for 4 seconds.")
				wscript.sleep 4000
				num_running = HowMany
			wend
			if pc_array(i) <> "" then
				wscript.echo(i & " of " & ubound(pc_array))
				wscript.echo("processes running: " & num_running)
				wscript.echo("next system: " & pc_array(i))
				wscript.echo("--------------")
				command1 = "cscript //nologo " & script_name & " " & pc_array(i) & " ldap=" & local_domain
				set sh1=wscript.createobject("wscript.shell")
				sh1.run command1, 6, false
				set sh1 = nothing
				num_running = HowMany
			end if
		next
	end if


	if audit_run_type = "remote" then
		for i = 0 to ubound(pc_array)
			while num_running > number_of_audits
				wscript.echo("processes running (" & num_running & ") greater than number wanted (" & number_of_audits & ")")
				wscript.echo("therefore - sleeping for 4 seconds.")
				wscript.sleep 4000
				num_running = HowMany
			wend
			if pc_array(i) <> "" then
				wscript.echo(i & " of " & ubound(pc_array))
				wscript.echo("processes running: " & num_running)
				wscript.echo("next system: " & pc_array(i))
				wscript.echo("--------------")
				remote_location = "\\"& pc_array(i) & "\admin$\"
				wscript.echo "Copying to: " & remote_location
				on error resume next
				objFSO.CopyFile "c:\temp\audit_windows.vbs", remote_location, True
				'objFSO.CopyFile "c:\xampplite\OAv2\other\bin\RMTSHARE.EXE", remote_location, True
				error_returned = Err.Number
				error_description = Err.Description
				on error goto 0
				if error_returned <> 0 then
					' we did not copy successfully
					wscript.echo "Error copying file. Audit not attempted. " & error_returned & " - " & error_description
				else
					' copy completed - now try to run the audit
					wscript.echo "Sleeping for two seconds."
					wscript.sleep 2000
					Set Command = WScript.CreateObject("WScript.Shell")
					' note - specify -d on the command below to run in non-interactive mode (locally)
					' if you specify -d you will see command windows of the remote processes
					cmd = "c:\temp\psexec.exe \\" & pc_array(i) & " -u " & remote_user & " -p " & remote_password & " -d cscript.exe " & remote_location & "audit_windows.vbs self_delete=y "
					wscript.echo "Running command: " & cmd
					on error resume next
					Command.Run (cmd)
					error_returned = Err.Number
					error_description = Err.Description
					on error goto 0
					if error_returned <> 0 then
						' we did not successfully start the audit
						wscript.echo "Error running audit. " & error_returned & " - " & error_description
					else
						wscript.echo "Audit started successfully."
					end if
					set Command = nothing
				end if
			end if
		next
	end if
next

Function HowMany()
  Dim Proc1,Proc2,Proc3
  CheckForHungWMI()
  Set Proc1 = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
  Set Proc2 = Proc1.ExecQuery("select * from win32_process" )
  HowMany=0
  For Each Proc3 in Proc2
    If LCase(Proc3.Caption) = "cscript.exe" Then
      HowMany=HowMany + 1
    End If
  Next
End Function

Sub CheckForHungWMI()
    ' Get the current date in UTC format
    Set dtmStart = CreateObject("WbemScripting.SWbemDateTime")
    dtmStart.SetVarDate Now, True

    ' Subtract the script_timeout value
    dtmNew = DateAdd("s", (script_timeout * -1), dtmStart.GetVarDate(True))

    ' Convert our dtmNew time back to UTC format, since that's the format needed for the WMIService query, below.
    Set dtmTarget = CreateObject("WbemScripting.SWbemDateTime")
    dtmTarget.SetVarDate dtmNew, True

    Set objWMIService = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
   
    ' Pull a list of all processes that are over (script_timeout) seconds old
    Set colProcesses = objWMIService.ExecQuery _
        ("Select * from Win32_Process WHERE CreationDate < '" & dtmTarget & "'")

    For each objProcess in colProcesses
        ' Look for cscript.exe processes only
        if objProcess.Name = "cscript.exe" then
            ' Look for audit.vbs processes with the //Nologo cmd line option. 
         ' NOTE: The //Nologo cmd line option should NOT be used to start the initial audit, or it will kill itself off after script_timeout seconds
            if InStr(objProcess.CommandLine, "//Nologo") and InStr(objProcess.CommandLine, "audit.vbs") then
            ' The command line looks something like this: "C:\WINDOWS\system32\cscript.exe" //Nologo audit.vbs COMPUTERNAME
            ' Get the position of audit.vbs in the command line, and add 10 to get to the start of the workstation name
            position = InStr(objProcess.CommandLine, "audit.vbs") + 10
            affectedComputer = Mid(objProcess.CommandLine,position)
            Echo("" & Now & "," & affectedComputer & " - Hung Process Killed. ")
            LogKilledAudit("Hung Process Killed for machine: " & affectedComputer)
                objProcess.Terminate
            end if
        end if
    Next
End Sub


Function LogKilledAudit(txt)
   on error resume next
   dim Today, YYYYmmdd, fp, txtarr, txtline, todaystr
   today=Now
   logfilename="killed_audits.log"
   todaystr=datepart("yyyy", today)&"/"&_
		right("00"&datepart("m", today), 2)&"/"&_
		right("00"&datepart("d", today), 2)&" "&_
		right("00"&datepart("h", today), 2)&":"&_
		right("00"&datepart("n", today), 2)&":"&_
		right("00"&datepart("s", today), 2)
   Set objFSO = CreateObject("Scripting.FileSystemObject")
   set fp=objFSO.OpenTextFile(logfilename, 8, true)
   If err<>0 then wscript.echo err.number&" "&err.description
   txtarr=Split(txt, vbcrlf)
   txt=""
   For each txtline in txtarr
		txtline=trim(txtline)
		if txtline<>"" then
			txt=txt&todaystr&" - "&txtline&vbcrlf
		End if
   Next
   WScript.Echo(left(txt, len(txt)-2))
   fp.write txt
   fp.Close
   set fp=Nothing
   LogKilledAudit=True
End Function 
