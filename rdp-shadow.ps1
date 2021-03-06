# Parameter-Definitionen
param(
    [Parameter(Mandatory=$false,Position=0)]
    [string]$Username="",
    [Parameter(Mandatory=$false,Position=1)]
    [string]$ComputerName=$env:Computername
)
# Fuer Mitteilungen als Dialogfenster fuegen wir den Typ hinzu
Add-Type -AssemblyName System.Windows.Forms
# Aus qwinsta-Ausgabe Objekte machen und diese in ein Array zusammenfassen
$Sessions=@()
(qwinsta /server:$ComputerName) | foreach {
    $objSession=New-Object System.Object
    $objSession | Add-Member -MemberType NoteProperty -Name Server -Value $ComputerName
    $objSession | Add-Member -MemberType NoteProperty -Name SessionID -Value $_.substring(40,8).trim()
    $objSession | Add-Member -MemberType NoteProperty -Name Type -Value $_.substring(1,3).trim()
    $objSession | Add-Member -MemberType NoteProperty -Name Username -Value $_.substring(19,22).trim()
    $objSession | Add-Member -MemberType NoteProperty -Name Status -Value $_.substring(48,8).trim()
    if($objSession.Username -ne "" -and $objSession.Username -ne "USERNAME" -and $objSesson.Username -notlike $env:username -and $objSession.Status -eq "Active") {
        $Sessions+=$objSession
    }
}
# Wir definieren globale Variabeln. Das braucht man, damit ein eigenes Dialogfenster die Auswahl global greifbar abspeichern kann..
$global:Username=$Username
$global:Controls=$false
$global:Prompt=$false
# Falls kein Benutzername per Parameter übergeben wurde, wird er hier erfragt (Buttons)
if($Username -eq "" -and $Sessions.Count -gt 0) {
    # Wir laden die Assemblies fuer eigene Formen / Fenster
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    # Das Dialogfenster wird definiert
    $objForm=New-Object System.Windows.Forms.Form
    $objForm.Text="Select session to shadow"
    $x=0
    $y=0
    # Und wir gehen nun die Sitzungen durch und erstellen jeweils einen Button an entspr. Position
    $Sessions | Sort-Object { $_.Username } | Foreach-Object {
        if($x -ge 3) {
            $y++
            $x=0
        }
        $objBtn=New-Object System.Windows.Forms.Button
        $objBtn.Location=New-Object System.Drawing.Size($(4+$x*200),$(4+$y*34))
        $objBtn.Size=New-Object System.Drawing.Size(190,24)
        $objBtn.Text=$_.Username
        # Und wenn man drauf klickt, wird die globale Variable beschrieben
        $objBtn.Add_Click({$global:Username=$this.Text;$objForm.Close()})
        $objForm.Controls.Add($objBtn)
        $x++
    }
    # Checkboxen
    $objCheckBox=New-Object System.Windows.Forms.CheckBox
    $objCheckBox.Location=New-Object System.Drawing.Size(4,$(4+($y+1)*34))
    $objCheckBox.AutoSize=$true
    $objCheckBox.Text="Take control"
    $objCheckBox.Checked=$global:Controls
    $objCheckBox.Add_Click({$global:Controls=$this.Checked})
    $objForm.Controls.Add($objCheckBox)
    $objCheckBox=New-Object System.Windows.Forms.CheckBox
    $objCheckBox.Location=New-Object System.Drawing.Size(100,$(4+($y+1)*34))
    $objCheckBox.AutoSize=$true
    $objCheckBox.Text="Ask user"
    $objCheckBox.Checked=$global:Prompt
    $objCheckBox.Add_Click({$global:Prompt=$this.Checked})
    # Positionierung und Groesse des Dialogfensters usw.
    $objForm.AutoSize=$true
    $objForm.AutoSizeMode="GrowAndShrink"
    $objForm.SizeGripStyle="Hide"
    $objForm.StartPosition="CenterScreen"
    $objForm.MinimizeBox = $False
    $objForm.MaximizeBox = $False
    # Dialogfenster anzeigen
    [void] $objForm.ShowDialog()
    $Username=$global:Username
}
$found=$false
# Finde die Sitzung des ausgewaehlten Benutzernamens
$Sessions | Where-Object { $_.Username -eq $Username } | Foreach-Object {
    $found=$true
    # Und spiegel die Sitzung, sofern sie aktiv ist.
    if($_.Status -eq "Active") {
        $sid=$_.SessionID
        $cmd="mstsc /v:$ComputerName /shadow:$sid"
        if($global:Controls) {
            $cmd="$cmd /control"
        }
        if($global:Prompt -ne $true) {
            $cmd="$cmd /noconsentprompt"
        }
        iex "& $cmd"
    }
    # Ansonsten entspr. Ausgabe tätigen.
    else {
        [System.Windows.Forms.MessageBox]::Show("Session of user '$Username' on $ComputerName is inactive.","Information",0,[System.Windows.Forms.MessageBoxIcon]::Information) >$null
    }
}
# Und wenn der Benutzername in der Liste nicht vorkommt, auhc entspr. Meldung ausgeben
if($found -eq $false -and $Username -ne "") {
    [System.Windows.Forms.MessageBox]::Show("User '$Username' seems to be not logged on to $ComputerName.","Information",0,[System.Windows.Forms.MessageBoxIcon]::Information) >$null
}
elseif($Sessions.Count -eq 0) {
    [System.Windows.Forms.MessageBox]::Show("There're no sessions to shadow on $ComputerName.","Information",0,[System.Windows.Forms.MessageBoxIcon]::Information) >$null
}
