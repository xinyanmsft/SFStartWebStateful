Param
(
    [Parameter(Mandatory=$True)]
    [String]
    $KeyVaultLocation,

    [Parameter(Mandatory=$True)]
    [String]
    $CertificateSecretName,

    [Parameter(Mandatory=$True)]
    [String]
    $CertificateDnsName,

    [Parameter(Mandatory=$True)]
    [SecureString]
    $SecureCertificatePassword,

    [Parameter(Mandatory=$True)]
    [String]
    $KeyVaultName,
    
    [Parameter(Mandatory=$True)]
    [String]
    $KeyVaultResourceGroupName,

    [Parameter(Mandatory=$True)]
    [String]
    $PfxFileOutputPath
)

$ErrorActionPreference = 'Stop'

# Create Certificate
$cert = New-SelfSignedCertificate `
    -CertStoreLocation "Cert:\LocalMachine\My" `
    -DnsName $CertificateDnsName

# Export Certificate as PFX
if (Test-Path $PfxFileOutputPath)
{
    $old = Remove-Item $PfxFileOutputPath -Force
}

$c = Export-PfxCertificate -Cert $cert -FilePath $PfxFileOutputPath -Password $SecureCertificatePassword

# Import to personal\my
$c2 = Import-PfxCertificate -FilePath $PfxFileOutputPath -CertStoreLocation "Cert:\CurrentUser\My" -Password $SecureCertificatePassword

# Create Key Vault
$keyVault = Get-AzureRmKeyVault -VaultName $KeyVaultName -ResourceGroupName $KeyVaultResourceGroupName -ErrorAction SilentlyContinue
if (!$keyVault){
	$keyVault = New-AzureRmKeyVault -VaultName $KeyVaultName -ResourceGroupName $KeyVaultResourceGroupName -Location $KeyVaultLocation -EnabledForDeployment
}

# Create Certificate
$certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $PfxFileOutputPath, $SecureCertificatePassword

# Convert Certificate to a secure string
$bytes = [System.IO.File]::ReadAllBytes($PfxFileOutputPath)
$base64 = [System.Convert]::ToBase64String($bytes)

$networkCredential = New-Object System.Net.NetworkCredential
$networkCredential.SecurePassword = $SecureCertificatePassword

$jsonBlob = @{
    data = $base64
    dataType = 'pfx'
    password = $networkCredential.Password
} | ConvertTo-Json

$jsonBlobBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonBlob)
$secretContent = [System.Convert]::ToBase64String($jsonBlobBytes)
$secretValue = ConvertTo-SecureString -String $secretContent -AsPlainText -Force

# Sometime Set-AzureKeyVaultSecret fail with 'the remote name could not be resolved'. Add some sleep to work around.
Sleep 15

# Register certificate as a secret in the key vault.

$s = Remove-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $CertificateSecretName -Force -Confirm:$false -ErrorAction Ignore

$s = Set-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $CertificateSecretName -SecretValue $secretValue
$certificateSecret = Get-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $CertificateSecretName -IncludeVersions

$result = @{
	'ServiceFabricCertificateThumbprint' = $($certificate.Thumbprint);
	'ServiceFabricKeyVaultId' = $($keyVault.ResourceId);
	'ServiceFabricCertificateSecretId' = $($certificateSecret.Id)
}
return $result
