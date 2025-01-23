# https://confidentialfiles.wordpress.com/2012/07/01/renaming-in-powershell-underscore-to-space/

dir . -recurse |
    where {-Not $_.PsIscontainer -AND $_.name -match " "} |
        foreach {
            $New=$_.name.Replace(" ","_")
            Rename-Item -path $_.Fullname -newname $New -passthru
        }

dir . -r |
    % { if ($_.Name -cne $_.Name.ToLower()) { ren $_.FullName $_.Name.ToLower() } }

