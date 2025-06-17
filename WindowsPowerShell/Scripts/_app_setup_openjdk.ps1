# https://jdk.java.net/java-se-ri/11-MR3

#<#
[Environment]::SetEnvironmentVariable("JAVA_HOME", "C:\Programs\jdk-11.0.0.2", "Machine")
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";" + "%JAVA_HOME%", "Machine")
#>
