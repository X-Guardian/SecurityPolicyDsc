$resourceModuleRootPath = Split-Path -Path (Split-Path $PSScriptRoot -Parent) -Parent
$modulesRootPath = Join-Path -Path $resourceModuleRootPath -ChildPath 'Modules'
Import-Module -Name (Join-Path -Path $modulesRootPath  `
        -ChildPath 'SecurityPolicyResourceHelper\SecurityPolicyResourceHelper.psm1') `
    -Force

#region HEADER

# Begin Testing
InModuleScope 'SecurityPolicyResourceHelper' {
    Describe 'Test helper functions' {

        Context 'Test ConvertTo-LocalFriendlyName' {
            $sid = 'S-1-5-32-544'
            It 'Should be BUILTIN\Administrators' {
                ConvertTo-LocalFriendlyName -Identity $sid | should be 'BUILTIN\Administrators'
            }

            It "Should return $env:COMPUTERNAME\administrator" {
                ConvertTo-LocalFriendlyName -Identity 'administrator' | Should be "$env:COMPUTERNAME\administrator"
            }

            It "Should not Throw when Scope is 'GET'" {
                {ConvertTo-LocalFriendlyName -Identity 'S-1-5-32-600' -Scope 'Get'} | Should Not throw
            }

            It "Should not Throw when Scope is Get and Identity is a unresolvable name" {
                {ConvertTo-LocalFriendlyName -Identity 'badName' -Scope 'Get'} | Should Not throw
            }

            It "Should Throw when Scope is Set and Identity is an unresolvable name" {
                {ConvertTo-LocalFriendlyName -Identity 'badName' -Scope 'Set'} | Should throw
            }
            It "Should Throw when Scope is 'SET'" {
                {ConvertTo-LocalFriendlyName -Identity 'S-1-5-32-600' -Scope 'Set'} | Should throw
            }
        }
        Context 'Test Invoke-Secedit' {
            Mock Start-Process

            $invokeSeceditParameters = @{
                InfPath       = 'temp.inf'
                SeceditOutput = 'output.txt'
                OverWrite     = $true
            }

            It 'Should not throw' {
                {Invoke-Secedit @invokeSeceditParameters} | Should not throw
            }

            It 'Should call Start-Process' {
                Assert-MockCalled -CommandName Start-Process -Exactly 1 -Scope Context
            }
        }
        Context 'Test Get-UserRightsAssignment' {
            $ini = "$PSScriptRoot..\..\..\Misc\TestHelpers\TestIni.txt"
            Mock -CommandName ConvertTo-LocalFriendlyName -MockWith {'Value1'}

            $result = Get-UserRightsAssignment $ini

            It 'Should match INI Section' {
                $result.Keys | Should Be 'section'
            }

            It 'Should match INI Comment' {
                $result.section.Comment1 | Should Be '; this is a comment'
            }

            It 'Should be Value1' {
                $result.section.Key1 | Should be 'Value1'
            }
        }
        Context 'Test Test-IdentityIsNull' {

            It 'Should return true when Identity is null' {
                $IdentityIsNull = Test-IdentityIsNull -Identity $null
                $IdentityIsNull | Should Be $true
            }
            It 'Should return true when Identity is empty' {
                $IdentityIsNull = Test-IdentityIsNull -Identity ''
                $IdentityIsNull | Should Be $true
            }
            It 'Should return false when Identity is Guest' {
                $IdentityIsNull = Test-IdentityIsNull -Identity 'Guest'
                $IdentityIsNull | Should Be $false
            }
        }
        Context 'Get-SecurityPolicy' {
            $ini = "$PSScriptRoot..\..\..\Misc\TestHelpers\sample.inf"
            $iniPath = Get-Item -Path $ini
            Mock -CommandName Join-Path -MockWith {$iniPath.FullName}
            Mock -CommandName Remove-Item -MockWith {}
            $securityPolicy = Get-SecurityPolicy -Area 'USER_RIGHTS'

            It 'Should return Builtin\Administrators' {
                $securityPolicy.SeLoadDriverPrivilege | Should Be 'BUILTIN\Administrators'
            }
        }
        Context 'Add-PolicyOption' {
            It 'Should have [System Access]' {
                [string[]]$testString = "EnableAdminAccount=1"
                [string]$addOptionResult = Add-PolicyOption -SystemAccessPolicies $testString

                $addOptionResult | Should Match '[System Access]'
            }
            It 'Should have [Kerberos Policy]' {
                [string[]]$testString = "MaxClockSkew=5"
                [string]$addOptionResult = Add-PolicyOption -KerberosPolicies $testString

                $addOptionResult | Should Match '[Kerberos Policy]'
            }
        }
        Context 'Test ConvertFrom-SDDLDescriptor' {
            It 'Should be "NT AUTHORITY\NETWORK"' {
                $identity = 'NU'
                ConvertFrom-SDDLDescriptor($identity) | should be 'NT AUTHORITY\NETWORK'
            }

            It "Should return 'S-1-5-32-544'" {
                $identity = 'S-1-5-32-544'
                ConvertFrom-SDDLDescriptor($identity) | Should be "S-1-5-32-544"
            }

            It "Should throw with ''" {
                $identity = ''
                {ConvertFrom-SDDLDescriptor($identity)} | Should throw
            }

            It "Accept from Pipe" {
                "SY" | ConvertFrom-SDDLDescriptor | Should be 'System'
            }

        }
        Context 'Test ConvertTo-SDDLDescriptor' {
            It 'Should be BA' {
                $identity = "BUILTIN\Administrators"
                ConvertTo-SDDLDescriptor($identity) | should be 'BA'
            }

            It 'Should be DA' {
                $identity = "Example.com\Domain Admins"
                ConvertTo-SDDLDescriptor($identity) | should be 'DA'
            }

            It "Should throw with ''" {
                $identity = ''
                {ConvertTo-SDDLDescriptor($identity)} | Should throw
            }

            It "Accept from Pipe" {
                "NT AUTHORITY\SELF" | ConvertTo-SDDLDescriptor | should be 'PS'
            }
        }
    }
}
