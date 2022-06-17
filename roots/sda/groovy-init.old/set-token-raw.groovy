@Grapes([
    @Grab('software.amazon.awssdk:secretsmanager:2.17.188'),
    @Grab('software.amazon.awssdk:sts:2.17.188')
])
import software.amazon.awssdk.regions.Region
import software.amazon.awssdk.services.secretsmanager.*
import software.amazon.awssdk.services.secretsmanager.model.*
import java.util.List
import hudson.model.User
import jenkins.security.ApiTokenProperty

def getValue(SecretsManagerClient secretsClient, String secretName) {
    try {
        GetSecretValueRequest valueRequest = GetSecretValueRequest.builder()
            .secretId(secretName)
            .build()

        GetSecretValueResponse valueResponse = secretsClient.getSecretValue(valueRequest)
        String secret = valueResponse.secretString()
        return secret
    } catch (SecretsManagerException e) {
        println e.awsErrorDetails().errorMessage()
        throw e
    }
}
// -------- START
String userName = 'ci-command-bot'
String tokenName = 'api-token-curr'
String regionStr = 'us-east-1'
String secretStr = 'sboardwell/test/jenkins/token'
Region region = Region.of(regionStr)
SecretsManagerClient secretsClient = SecretsManagerClient.builder()
        .region(region)
        .build()
try {
    String tok = getValue(secretsClient, secretStr)
    User user = User.get(userName)
 	if (!user.getProperty(ApiTokenProperty.class)) {
	    user.addProperty(new ApiTokenProperty())
    }
  	user.getProperty(ApiTokenProperty.class).addFixedNewToken(tokenName, tok)
} catch (SecretsManagerException e) {
    println e.awsErrorDetails().errorMessage()
    throw e
} finally {
    secretsClient.close()
}
