

Function Get-Filename($initialDirectory){
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "RBXMX (*.rbxmx)| *.rbxmx"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}


Function Remove-Keyframes($filename){

    $newFilename = $filename.Substring(0,$filename.LastIndexOf(".")) + "_new" + $filename.Substring($filename.LastIndexOf("."))

    [XML]$xml = gc $filename
    $keyframeSequence = select-xml -Xml $xml -XPath "//Item[@class='KeyframeSequence']" 
    if ($null -eq $keyframeSequence) {

        Write-Error "The selected file does not contain the right structure. The first Item node must be a KeyframeSequence class node."
    }

    #get all partnames in the XML
    $partNames = select-xml -Xml $xml -XPath "//Item/Properties/string" | % {$_.Node.InnerText} | ? {$_ -ne "Keyframe" } | ? {$_ -ne "End"} | Sort -Unique
    if ($null -eq $partNames) {

        Write-Error "The selected file does not contain the right structure. There are no pose nodes with part names."
    }

    $poseNodesDeleted = 0

    foreach ($partName in $partNames) {
        Write-Host "================================================================================================="
        Write-Host "Part name = " $PartName


        #iterate through the partnames and find all keyframes with that partname    
        $partKeyFrames = $xml.SelectNodes("//Item/Properties/string[text()='$partName']/./ancestor::Item[@class='Keyframe']")
        if ($null  -eq $partKeyFrames) {
            Write-Host "No keyframes for $($partName)"
            continue
        }

        ##Get all times from the keyframes for that part
        [System.Collections.ArrayList]$keyframeTimes = $partkeyFrames | select-xml -XPath "//float[@name='Time']" | Select-Object -ExpandProperty Node | Select -ExpandProperty InnerText | Sort -Unique
        if ($null -eq $keyframeTimes) {
            Write-Host "No keyframe times for $($partName)"
            continue
        }

        # Note: Never delete the last keyframe or that may make the animation jumpy while looping
        #       To do this, just remove the last keyframetime so it doesn't get compared
        $keyframeTimes.RemoveAt($keyframeTimes.Count - 1)

        Write-Verbose "# of keyframes for this part: '$($keyframeTimes.Count)"

        
        
        #iterate through each keyframe time slot that has this partName and find if the next n keyframes have the same CFrame coordinates for this partName
        for ($i = 0; $i -le $keyframeTimes.Count; $i++) { 
            $time = $keyframeTimes[$i]

            #Write-Host "KeyFrame time '$i' of '$($keyframeTimes.Count)' : $time "

            


            $thisFrame = $xml.SelectSingleNode("//Item[@class='Keyframe']/Properties/float[@name='Time'][text()='$time']/../..//child::Item/Properties/string[text()='$partName']/../CoordinateFrame")
            if (($null -eq $thisFrame) -or ($null -eq $thisFrame.ChildNodes)) {continue}

            Write-Verbose $thisFrame.InnerXml

            $j = $i + 1
            $nextFrame = $null

            $timeNext = $keyframeTimes[$j]
            $nextFrame = $xml.SelectSingleNode("//Item[@class='Keyframe']/Properties/float[@name='Time'][text()='$timeNext']/../..//child::Item/Properties/string[text()='$partName']/../CoordinateFrame")
            $matched = $true

            

            while (($matched -eq $true) -and ($null -ne $nextFrame) -and ($null -ne $nextFrame.ChildNodes))  {

                Write-Verbose "Comparing pose node time '$($time)' vs. '$($timeNext)'"

                foreach ($node in $thisFrame.ChildNodes) {

                    #compare the nodes based on the CFrame coordinate value rounded to 2 decimal places. 

                    [decimal]$currentNodeValue = $($node.InnerText) -as [decimal]
                    [decimal]$nextNodeValue = $($nextFrame[$node.Name].InnerText) -as [decimal]

                    $currentNodeValue = [math]::Round($currentNodeValue,2)
                    $nextNodeValue = [math]::Round($nextNodeValue,2)

                    Write-Verbose "Comparing thisFrame vs NextFrame:  $($node.Name) = $($currentNodeValue) / $($nextNodeValue)"

                    if ($node.Name.StartsWith("R")) {
                        
                        if ($currentNodeValue -ne $nextNodeValue) {
                            Write-Verbose "No match:  $($node.Name) = $($currentNodeValue) / $($nextNodeValue)"
                            $matched = $false
                        }
                    }
                    # ignore the XYZ coordinates
                    # elseif ($node.InnerText -ne $nextFrame[$node.Name].InnerText) { 
                    #    $matched = $false
                    # }

                    if ($matched -eq $false) { 
                        Write-Verbose "NextFrame doesn't match"
                        Write-Verbose "  "
                        Write-Verbose " =====  Saving $($partName) pose node at time:  $($timeNext)   ====="  
                        Write-Verbose "  "
                        break 
                    }   
            
                } #endforeach

                if ($matched) {
                #  Write-Host "NextFrame matched ThisFrame. Deleting nextFrame."
                    $nodeToDelete = $xml.SelectSingleNode("//Item[@class='Keyframe']/Properties/float[@name='Time'][text()='$timeNext']/../..//child::Item/Properties/string[text()='$partName']/..")
                    Write-Verbose "  "
                    Write-Verbose " >>>>>  Deleting $($partName) pose node at time:  $($timeNext)   <<<<<"  
                    Write-Verbose "  "
                
                    if ($null -eq $nodeToDelete) {
                        Write-Verbose "Couldn't find nodeToDelete!"
                    }
                    else {
                        $nodeToDelete.ParentNode.RemoveChild($nodeToDelete) | Out-Null
                        $poseNodesDeleted++
                        
                        # skip the next keyframe time for getting "thisFrame" since we just deleted the node for that time
                        $i++

                    }
                }

                $j++
                $timeNext = $keyframeTimes[$j]
                Write-Verbose "NextTime:  $timeNext"
                $nextFrame = $xml.SelectSingleNode("//Item[@class='Keyframe']/Properties/float[@name='Time'][text()='$timeNext']/../..//child::Item/Properties/string[text()='$partName']/../CoordinateFrame")
            

            } 
        # Write-Host "No more sequential matches to keyframe"
            


        }
        
        Write-Verbose "End of Part name = $PartName"
        Write-Verbose "================================================================================================="
        
            
    }
    Write-Host "Total pose nodes deleted = $poseNodesDeleted"



    # Clean up empty "Pose" tags
    $nodesToDelete = $xml.SelectNodes("//Item[@class='Pose'][not(normalize-space())]") 

    while ($null -ne $nodesToDelete) {
        foreach ($node in $nodesToDelete) {
            $node.ParentNode.RemoveChild($node) | Out-Null
        }

        $nodesToDelete = $xml.SelectNodes("//Item[@class='Pose'][not(normalize-space())]") 

    }

    Write-Host "Finished editing. Saving file. "

    $xml.Save($newFilename)
}


$filename = Get-Filename $env:USERPROFILE
if ($null -ne $filename) {
    Remove-Keyframes $filename
}


