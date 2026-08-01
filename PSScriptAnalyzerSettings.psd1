@{
    Severity     = @('Error', 'Warning')
    IncludeRules = @(
        'PSAvoidUsingCmdletAliases'
        'PSAvoidUsingEmptyCatchBlock'
        'PSAvoidUsingInvokeExpression'
        'PSAvoidUsingPlainTextForPassword'
        'PSAvoidUsingUsernameAndPasswordParams'
        'PSUseApprovedVerbs'
        'PSUseBOMForUnicodeEncodedFile'
        'PSUseDeclaredVarsMoreThanAssignments'
    )
    Rules        = @{
        PSAvoidUsingPlainTextForPassword = @{
            AllowNullOrEmptyString = $false
        }
    }
}
