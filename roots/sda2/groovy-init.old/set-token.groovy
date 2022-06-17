import jenkins.*
import jenkins.model.*
import jenkins.security.ApiTokenProperty
import hudson.*
import hudson.model.*
// -------- START
String userName = 'ci-command-bot'
String tokenName = 'api-token-from-creds'
String secretStr = 'sboardwell/test/jenkins/token'

def jenkinsCredentials = com.cloudbees.plugins.credentials.CredentialsProvider.lookupCredentials(
        com.cloudbees.plugins.credentials.Credentials.class,
        Jenkins.instance,
        null,
        null
);
for (creds in jenkinsCredentials) {
  if(creds.id == secretStr){
    String tok = creds.secret
    User user = User.get(userName)
 	if (!user.getProperty(ApiTokenProperty.class)) {
	    user.addProperty(new ApiTokenProperty())
    }
    user.getProperty(ApiTokenProperty.class).addFixedNewToken(tokenName, tok)
  }
}