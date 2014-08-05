#!/bin/sh -e
#
# Shibboleth installation script
#
##################################################################
#source common parts
. `dirname $0`/lib_common.sh
. `dirname $0`/lib_logging.sh

function usage()
{
    echo "ERROR: $EXENAME: Not enough input arguments!" >&2
    echo "USAGE: $EXENAME <idp-cert> <sp-cert> <sp-key> [<sp-ca-cert> [<sp-cert-chain>]]" >&2
    echo "OPTIONS:" >&2
    echo "    <idp-cert>  Identity Provider (IdP) certificate." >&2
    echo "    <sp-cert>  Service Provider (SP) certificate." >&2
    echo "    <sp-key>  SP certificate." >&2
    echo "    <sp-ca-cert>  SP Certificate Authority (CA) root certificate." >&2
    echo "    <sp-cert-chain>  SP CA certification chain." >&2
    echo "NOTE: All inputs must be in the PEM format." >&2
    exit 1
}

function instcrt()
{
    info "... $2 -> $1"
    cat < "$2" > "$1"
}

[ $# -lt 3 ] && { usage ; exit 1 ; }

##################################################################
# configuration - change as needed

# locations of the certificates
IDP_CERT_FILE="$1"
SP_CERT_FILE="$2"
SP_KEY_FILE="$3"
SP_CERT_CA_FILE="$4"
SP_CERT_CHAIN_FILE="$4"

# Service Provider configuration
SP_HOST="dream.eox.at"         # SP host name
SP_NAME="v-manip"              # SP name
SP_ENTITYID="https://$SP_HOST/shibboleth"
SP_CONTACT="webmaster@eox.at"
SP_HOME_FULL_URL="http://eox.at"
SP_HOME_BASE_URL="https://$SP_HOST"
SP_EXTENSION="eox.at"
SP_ORG_DISP_NAME="DREAM ODA-OS Server"

# Identity Provider configuration
IDP_HOST="idp.v-manip.eox.at"  # IdP host name
IDP_PORT="443"      # IdP HTTPS port
IDP_SOAP="8443"     # IdP SOAP port 
IDP_ENTITYID="https://$IDP_HOST/shibboleth"

# host specific configuration
PROTECTED_DIR="/"

# locations of the target installed keys and certificates
SHIB_SP_KEY_FILE="/etc/shibboleth/sp-key.pem"                 #SP key
SHIB_SP_CERT_FILE="/etc/shibboleth/sp-cert.pem"               #SP certificate
SHIB_IDP_CERT_FILE="/etc/shibboleth/idp-cert.pem"             #IDP certificate

# end of configuration
##################################################################

#NOTE:
#If you change the configuration of Shibboleth, you need to copy the generated
#'sp-metadata.xml' and 'idp-metadata.xml' to the IDP machine in the folder
#'/opt/shibboleth-idp/metadata'. The file 'relying-party.xml' must be copied
#to the folder '/opt/shibboleth-idp/conf' on the IDP machine."

info "Installing Shibboleth ..."

# Add the shibboleth rpm repository.
if [ ! -f "/etc/yum.repos.d/security:shibboleth.repo" ]
then
    wget 'http://download.opensuse.org/repositories/security://shibboleth/CentOS_CentOS-6/security:shibboleth.repo' -P '/etc/yum.repos.d'
fi

# Set exclude 'libxerces' loading from the security:shibboleth.repo.
ex /etc/yum.repos.d/security:shibboleth.repo <<END
g/^[ 	]*exclude[ 	]*=/d
/^[ 	]*\[security_shibboleth\]/a
exclude=libxerces-c-3_1
.
wq
END

# Install required RPM packages.
yum install -y shibboleth mod_ssl openssl

# Delete the pre-existing config files.
for CONF in /etc/shibboleth/attribute-policy.xml /etc/shibboleth/attribute-map.xml /etc/shibboleth/shibboleth2.xml
do
    [ -f "$CONF" ] && rm -fv "$CONF"
done

info "Installing x509 Certificates ..."

# Installing the certificates  certificate. 
instcrt "$SHIB_IDP_CERT_FILE" "$IDP_CERT_FILE"
instcrt "$SHIB_SP_CERT_FILE" "$SP_CERT_FILE"
instcrt "$SHIB_SP_KEY_FILE" "$SP_KEY_FILE"

info "Configuring Shibboleth ..."

# attribute-map.xml
info "... /etc/shibboleth/attribute-map.xml"
cat >/etc/shibboleth/attribute-map.xml <<EOF
<Attributes xmlns="urn:mace:shibboleth:2.0:attribute-map" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <Attribute name="urn:oid:2.5.4.3" id="commonName" />
    <Attribute name="urn:oid:2.5.4.4" id="surname" />
    <Attribute name="urn:oid:0.9.2342.19200300.100.1.1" id="uid" />
</Attributes>
EOF

# attribute-policy.xml
info "... /etc/shibboleth/attribute-policy.xml"
cat >/etc/shibboleth/attribute-policy.xml <<EOF
<afp:AttributeFilterPolicyGroup
    xmlns="urn:mace:shibboleth:2.0:afp:mf:basic" xmlns:basic="urn:mace:shibboleth:2.0:afp:mf:basic" xmlns:afp="urn:mace:shibboleth:2.0:afp" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <afp:AttributeFilterPolicy>
        <afp:PolicyRequirementRule xsi:type="ANY"/>
        <afp:AttributeRule attributeID="*">
            <afp:PermitValueRule xsi:type="ANY"/>
        </afp:AttributeRule>
    </afp:AttributeFilterPolicy>
</afp:AttributeFilterPolicyGroup>
EOF

# idp-metadata.xml
info "... /etc/shibboleth/idp-metadata.xml"
cat >/etc/shibboleth/idp-metadata.xml <<EOF
<EntityDescriptor entityID="$IDP_ENTITYID" validUntil="2030-01-01T00:00:00Z"
                  xmlns="urn:oasis:names:tc:SAML:2.0:metadata"
                  xmlns:ds="http://www.w3.org/2000/09/xmldsig#"
                  xmlns:shibmd="urn:mace:shibboleth:metadata:1.0"
                  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <IDPSSODescriptor protocolSupportEnumeration="urn:mace:shibboleth:1.0 urn:oasis:names:tc:SAML:1.1:protocol urn:oasis:names:tc:SAML:2.0:protocol">
        <Extensions>
            <shibmd:Scope regexp="false">$SP_EXTENSION</shibmd:Scope>
        </Extensions>
        <KeyDescriptor>
            <ds:KeyInfo>
                <ds:X509Data>
                    <ds:X509Certificate>
`cat "$IDP_CERT_FILE" | grep -v CERTIFICATE`
                    </ds:X509Certificate>
                </ds:X509Data>
            </ds:KeyInfo>
        </KeyDescriptor>
        <ArtifactResolutionService Binding="urn:oasis:names:tc:SAML:1.0:bindings:SOAP-binding" Location="https://$IDP_HOST:$IDP_SOAP/idp/profile/SAML1/SOAP/ArtifactResolution" index="1"/>
        <ArtifactResolutionService Binding="urn:oasis:names:tc:SAML:2.0:bindings:SOAP" Location="https://$IDP_HOST:$IDP_SOAP/idp/profile/SAML2/SOAP/ArtifactResolution" index="2"/>
        <NameIDFormat>urn:mace:shibboleth:1.0:nameIdentifier</NameIDFormat>
        <NameIDFormat>urn:oasis:names:tc:SAML:2.0:nameid-format:transient</NameIDFormat>
        <SingleSignOnService Binding="urn:mace:shibboleth:1.0:profiles:AuthnRequest" Location="https://$IDP_HOST:$IDP_PORT/idp/profile/Shibboleth/SSO" />
        <SingleSignOnService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect" Location="https://$IDP_HOST:$IDP_PORT/idp/profile/SAML2/Redirect/SSO" />
        <SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect" Location="https://$IDP_HOST:$IDP_PORT/idp/profile/SAML2/Redirect/SLO" ResponseLocation="https://$IDP_HOST:$IDP_PORT/idp/profile/SAML2/Redirect/SLO"/>
    </IDPSSODescriptor>
    <AttributeAuthorityDescriptor protocolSupportEnumeration="urn:oasis:names:tc:SAML:1.1:protocol urn:oasis:names:tc:SAML:2.0:protocol">
        <Extensions>
            <shibmd:Scope regexp="false">$SP_EXTENSION</shibmd:Scope>
        </Extensions>
        <KeyDescriptor>
            <ds:KeyInfo>
                <ds:X509Data>
                    <ds:X509Certificate>
`cat "$IDP_CERT_FILE" | grep -v CERTIFICATE`
                    </ds:X509Certificate>
                </ds:X509Data>
            </ds:KeyInfo>
        </KeyDescriptor>
        <AttributeService Binding="urn:oasis:names:tc:SAML:1.0:bindings:SOAP-binding" Location="https://$IDP_HOST:$IDP_SOAP/idp/profile/SAML1/SOAP/AttributeQuery" />
        <AttributeService Binding="urn:oasis:names:tc:SAML:2.0:bindings:SOAP" Location="https://$IDP_HOST:$IDP_SOAP/idp/profile/SAML2/SOAP/AttributeQuery" />
        <NameIDFormat>urn:mace:shibboleth:1.0:nameIdentifier</NameIDFormat>
        <NameIDFormat>urn:oasis:names:tc:SAML:2.0:nameid-format:transient</NameIDFormat>
    </AttributeAuthorityDescriptor>
</EntityDescriptor>
EOF

# shibboleth2.xml
info "... /etc/shibboleth/sp-shibboleth2.xml"
cat >/etc/shibboleth/shibboleth2.xml <<EOF
<SPConfig xmlns="urn:mace:shibboleth:2.0:native:sp:config"
    xmlns:conf="urn:mace:shibboleth:2.0:native:sp:config"
    xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion"
    xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol"
    xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
    logger="syslog.logger" clockSkew="7600">
    <!-- The OutOfProcess section contains properties affecting the shibd daemon. -->
    <OutOfProcess logger="shibd.logger">
        <!--
        <Extensions>
            <Library path="odbc-store.so" fatal="true"/>
        </Extensions>
        -->
    </OutOfProcess>
    <!-- Only one listener can be defined, to connect in-process modules to shibd. -->
    <UnixListener address="shibd.sock"/>
    <!-- <TCPListener address="127.0.0.1" port="1600" acl="127.0.0.1"/> -->
    <!-- This set of components stores sessions and other persistent data in daemon memory. -->
    <StorageService type="Memory" id="mem" cleanupInterval="900"/>
    <SessionCache type="StorageService" StorageService="mem" cacheAssertions="false"
                  cacheAllowance="900" inprocTimeout="900" cleanupInterval="900"/>
    <ReplayCache StorageService="mem"/>
    <ArtifactMap artifactTTL="180"/>
    <!-- This set of components stores sessions and other persistent data in an ODBC database. -->
    <!--
    <StorageService type="ODBC" id="db" cleanupInterval="900">
        <ConnectionString>
        DRIVER=drivername;SERVER=dbserver;UID=shibboleth;PWD=password;DATABASE=shibboleth;APP=Shibboleth
        </ConnectionString>
    </StorageService>
    <SessionCache type="StorageService" StorageService="db" cacheAssertions="false"
                  cacheTimeout="3600" inprocTimeout="900" cleanupInterval="900"/>
    <ReplayCache StorageService="db"/>
    <ArtifactMap StorageService="db" artifactTTL="180"/>
    -->
    <!--
    To customize behavior for specific resources on Apache, and to link vhosts or
    resources to ApplicationOverride settings below, use web server options/commands.
    See https://wiki.shibboleth.net/confluence/display/SHIB2/NativeSPConfigurationElements for help.

    For examples with the RequestMap XML syntax instead, see the example-shibboleth2.xml
    file, and the https://wiki.shibboleth.net/confluence/display/SHIB2/NativeSPRequestMapHowTo topic.
    -->
    <RequestMapper type="Native">
        <RequestMap>
            <!--
            The example requires a session for documents in $PROTECTED_DIR on the containing host with http and
            https on the default ports. Note that the name and port in the <Host> elements MUST match
            Apache's ServerName and Port directives or the IIS Site name in the <ISAPI> element above.
            -->
            <Host name="$SP_HOST">
                <Path name="$PROTECTED_DIR" authType="shibboleth" requireSession="true"/>
            </Host>
        </RequestMap>
    </RequestMapper>
    <!--
    The ApplicationDefaults element is where most of Shibboleth's SAML bits are defined.
    Resource requests are mapped by the RequestMapper to an applicationId that
    points into to this section (or to the defaults here).
    -->
    <ApplicationDefaults entityID="https://$SP_HOST/shibboleth"
                         REMOTE_USER="eppn persistent-id targeted-id"
                         metadataAttributePrefix="Meta-"
                         signing="false" encryption="false">
        <!--
        Controls session lifetimes, address checks, cookie handling, and the protocol handlers.
        You MUST supply an effectively unique handlerURL value for each of your applications.
        The value defaults to /Shibboleth.sso, and should be a relative path, with the SP computing
        a relative value based on the virtual host. Using handlerSSL="true", the default, will force
        the protocol to be https. You should also set cookieProps to "https" for SSL-only sites.
        Note that while we default checkAddress to "false", this has a negative impact on the
        security of your site. Stealing sessions via cookie theft is much easier with this disabled.
        -->
        <Sessions lifetime="7200" timeout="3600" checkAddress="false"
            handlerURL="/Shibboleth.sso" handlerSSL="false" cookieProps="http" relayState="ss:mem"
            exportLocation="http://localhost/Shibboleth.sso/GetAssertion" exportACL="127.0.0.1"
            idpHistory="false" idpHistoryDays="7">
            <!--
            The "stripped down" files use the shorthand syntax for configuring handlers.
            This uses the old "every handler specified directly" syntax. You can replace
            or supplement the new syntax following these examples.
            -->
            <!--
            SessionInitiators handle session requests and relay them to a Discovery page,
            or to an IdP if possible. Automatic session setup will use the default or first
            element (or requireSessionWith can specify a specific id to use).
            -->
            <SessionInitiator type="SAML2" entityID="$IDP_ENTITYID" forceAuthn="false" Location="/Login" template="/etc/shibboleth/bindingTemplate.html"/>
            <!--
            md:AssertionConsumerService locations handle specific SSO protocol bindings,
            such as SAML 2.0 POST or SAML 1.1 Artifact. The isDefault and index attributes
            are used when sessions are initiated to determine how to tell the IdP where and
            how to return the response.
            -->
            <md:AssertionConsumerService Location="/SAML2/POST" index="1"
                Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"/>
            <md:AssertionConsumerService Location="/SAML2/POST-SimpleSign" index="2"
                Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST-SimpleSign"/>
            <md:AssertionConsumerService Location="/SAML2/Artifact" index="3"
                Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Artifact"/>
            <md:AssertionConsumerService Location="/SAML2/ECP" index="4"
                Binding="urn:oasis:names:tc:SAML:2.0:bindings:PAOS"/>
            <md:AssertionConsumerService Location="/SAML/POST" index="5"
                Binding="urn:oasis:names:tc:SAML:1.0:profiles:browser-post"/>
            <md:AssertionConsumerService Location="/SAML/Artifact" index="6"
                Binding="urn:oasis:names:tc:SAML:1.0:profiles:artifact-01"/>
            <!-- LogoutInitiators enable SP-initiated local or global/single logout of sessions. -->
            <LogoutInitiator type="Local" Location="/Logout" template="/etc/shibboleth/bindingTemplate.html" />
            <LogoutInitiator type="SAML2" Location="/SLogout" template="/etc/shibboleth/bindingTemplate.html" />
            <!-- md:SingleLogoutService locations handle single logout (SLO) protocol messages. -->
            <md:SingleLogoutService Location="/SLO/SOAP"
                Binding="urn:oasis:names:tc:SAML:2.0:bindings:SOAP"/>
            <md:SingleLogoutService Location="/SLO/Redirect" conf:template="bindingTemplate.html"
                Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect"/>
            <md:SingleLogoutService Location="/SLO/POST" conf:template="bindingTemplate.html"
                Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"/>
            <md:SingleLogoutService Location="/SLO/Artifact" conf:template="bindingTemplate.html"
                Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Artifact"/>
            <!-- md:ManageNameIDService locations handle NameID management (NIM) protocol messages. -->
            <md:ManageNameIDService Location="/NIM/SOAP"
                Binding="urn:oasis:names:tc:SAML:2.0:bindings:SOAP"/>
            <md:ManageNameIDService Location="/NIM/Redirect" conf:template="bindingTemplate.html"
                Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect"/>
            <md:ManageNameIDService Location="/NIM/POST" conf:template="bindingTemplate.html"
                Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"/>
            <md:ManageNameIDService Location="/NIM/Artifact" conf:template="bindingTemplate.html"
                Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Artifact"/>
            <!--
            md:ArtifactResolutionService locations resolve artifacts issued when using the
            SAML 2.0 HTTP-Artifact binding on outgoing messages, generally uses SOAP.
            -->
            <md:ArtifactResolutionService Location="/Artifact/SOAP" index="1"
                Binding="urn:oasis:names:tc:SAML:2.0:bindings:SOAP"/>
            <!-- Extension service that generates "approximate" metadata based on SP configuration. -->
            <Handler type="MetadataGenerator" Location="/Metadata" signing="false"/>
            <!-- Status reporting service. -->
            <Handler type="Status" Location="/Status" acl="127.0.0.1 ::1"/>
            <!-- Session diagnostic service. -->
            <Handler type="Session" Location="/Session" showAttributeValues="false"/>
            <!-- JSON feed of discovery information. -->
            <Handler type="DiscoveryFeed" Location="/DiscoFeed"/>
        </Sessions>
        <!--
        Allows overriding of error template information/filenames. You can
        also add attributes with values that can be plugged into the templates.
        -->
        <Errors session="/etc/shibboleth/sessionError.html" metadata="/etc/shibboleth/metadataError.html" access="/etc/shibboleth/accessError.html" ssl="/etc/shibboleth/sslError.html" supportContact="webmaster@eox.at" logoLocation="/shibboleth-sp/logo.jpg" styleSheet="/shibboleth-sp/main.css" globalLogout="/etc/shibboleth/globalLogout.html" localLogout="/etc/shibboleth/localLogout.html"></Errors>
        <!--
        Uncomment and modify to tweak settings for specific IdPs or groups. Settings here
        generally match those allowed by the <ApplicationDefaults> element.
        -->
        <RelyingParty Name="$IDP_ENTITYID/shibboleth" keyName="defcreds"/>
        <MetadataProvider type="Chaining">
            <MetadataProvider type="XML" file="/etc/shibboleth/idp-metadata.xml"/>
            <MetadataProvider type="XML" file="/etc/shibboleth/sp-metadata.xml"/>
        </MetadataProvider>
        <!-- TrustEngines run in order to evaluate peer keys and certificates. -->
        <TrustEngine type="Chaining">
            <TrustEngine type="ExplicitKey"/>
            <TrustEngine type="PKIX"/>
        </TrustEngine>
        <!-- Map to extract attributes from SAML assertions. -->
        <AttributeExtractor type="XML" validate="true" reloadChanges="false" path="attribute-map.xml"/>
        <!-- Extracts support information for IdP from its metadata. -->
        <AttributeExtractor type="Metadata" errorURL="errorURL" DisplayName="displayName"/>
        <!-- Use a SAML query if no attributes are supplied during SSO. -->
        <AttributeResolver type="Query" subjectMatch="true"/>
        <!-- Default filtering policy for recognized attributes, lets other data pass. -->
        <AttributeFilter type="XML" validate="true" path="attribute-policy.xml"/>
        <!-- Simple file-based resolver for using a single keypair. -->
        <CredentialResolver type="File" key="/etc/shibboleth/sp-key.pem" certificate="/etc/shibboleth/sp-cert.pem" keyName="defcreds"/>
        <!--
        The default settings can be overridden by creating ApplicationOverride elements (see
        the https://wiki.shibboleth.net/confluence/display/SHIB2/NativeSPApplicationOverride topic).
        Resource requests are mapped by web server commands, or the RequestMapper, to an
        applicationId setting.

        Example of a second application (for a second vhost) that has a different entityID.
        Resources on the vhost would map to an applicationId of "admin":
        -->
        <!--
        <ApplicationOverride id="admin" entityID="https://admin.example.org/shibboleth"/>
        -->
    </ApplicationDefaults>
    <!-- Policies that determine how to process and authenticate runtime messages. -->
    <SecurityPolicyProvider type="XML" validate="true" path="security-policy.xml"/>
    <!-- Low-level configuration about protocols and bindings available for use. -->
    <ProtocolProvider type="XML" validate="true" reloadChanges="false" path="protocols.xml"/>
</SPConfig>
EOF

# sp-metadata.xml
info "... /etc/shibboleth/sp-metadata.xml"
cat >/etc/shibboleth/sp-metadata.xml <<EOF
<EntityDescriptor entityID="$SP_ENTITYID" validUntil="2030-01-01T00:00:00Z"
                  xmlns="urn:oasis:names:tc:SAML:2.0:metadata"
                  xmlns:ds="http://www.w3.org/2000/09/xmldsig#"
                  xmlns:shibmd="urn:mace:shibboleth:metadata:1.0"
                  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <SPSSODescriptor protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">
        <KeyDescriptor>
            <ds:KeyInfo>
                <ds:X509Data>
                    <ds:X509Certificate>
`cat "$SP_CERT_FILE" | grep -v CERTIFICATE`
                    </ds:X509Certificate>
                </ds:X509Data>
            </ds:KeyInfo>
        </KeyDescriptor>
        <!-- This tells IdPs that Single Logout is supported and where/how to request it. -->
        <SingleLogoutService
            Binding="urn:oasis:names:tc:SAML:2.0:bindings:SOAP"
            Location="https://$SP_HOST/Shibboleth.sso/SLO/SOAP" xmlns="urn:oasis:names:tc:SAML:2.0:metadata"/>
        <SingleLogoutService
            Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect"
            Location="https://$SP_HOST/Shibboleth.sso/SLO/Redirect" xmlns="urn:oasis:names:tc:SAML:2.0:metadata"/>
        <SingleLogoutService
            Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
            Location="https://$SP_HOST/Shibboleth.sso/SLO/POST" xmlns="urn:oasis:names:tc:SAML:2.0:metadata"/>
        <SingleLogoutService
            Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Artifact"
            Location="https://$SP_HOST/Shibboleth.sso/SLO/Artifact" xmlns="urn:oasis:names:tc:SAML:2.0:metadata"/>
        <!--
            This tells IdPs where and how to push assertions through the browser. Mostly
            the SP will tell the IdP what location to use in its request, but this
            is how the IdP validates the location and also figures out which
            SAML version/binding to use.
            -->
        <AssertionConsumerService
            Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
            Location="https://$SP_HOST/Shibboleth.sso/SAML2/POST"
            index="1" isDefault="true" xmlns="urn:oasis:names:tc:SAML:2.0:metadata"/>
        <AssertionConsumerService
            Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST-SimpleSign"
            Location="https://$SP_HOST/Shibboleth.sso/SAML2/POST-SimpleSign"
            index="2" xmlns="urn:oasis:names:tc:SAML:2.0:metadata"/>
        <AssertionConsumerService
            Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Artifact"
            Location="https://$SP_HOST/Shibboleth.sso/SAML2/Artifact"
            index="3" xmlns="urn:oasis:names:tc:SAML:2.0:metadata"/>
        <AssertionConsumerService
            Binding="urn:oasis:names:tc:SAML:1.0:profiles:browser-post"
            Location="https://$SP_HOST/Shibboleth.sso/SAML/POST"
            index="4" xmlns="urn:oasis:names:tc:SAML:2.0:metadata"/>
        <AssertionConsumerService
            Binding="urn:oasis:names:tc:SAML:1.0:profiles:artifact-01"
            Location="https://$SP_HOST/Shibboleth.sso/SAML/Artifact"
            index="5" xmlns="urn:oasis:names:tc:SAML:2.0:metadata"/>
        <!-- This tells IdPs that you only need transient identifiers. -->
        <NameIDFormat>urn:oasis:names:tc:SAML:2.0:nameid-format:transient</NameIDFormat>
    </SPSSODescriptor>
    <Organization>
        <OrganizationName xml:lang="en">$SP_NAME</OrganizationName>
        <OrganizationDisplayName xml:lang="en">$SP_ORG_DISP_NAME</OrganizationDisplayName>
        <OrganizationURL xml:lang="en">$SP_HOME_FULL_URL</OrganizationURL>
    </Organization>
</EntityDescriptor>
EOF

# relying-party.xml
info "... /etc/shibboleth/relying-party.xml"
cat >/etc/shibboleth/relying-party.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<rp:RelyingPartyGroup xmlns:rp="urn:mace:shibboleth:2.0:relying-party"
                   xmlns:saml="urn:mace:shibboleth:2.0:relying-party:saml"
                   xmlns:metadata="urn:mace:shibboleth:2.0:metadata"
                   xmlns:resource="urn:mace:shibboleth:2.0:resource"
                   xmlns:security="urn:mace:shibboleth:2.0:security"
                   xmlns:samlsec="urn:mace:shibboleth:2.0:security:saml"
                   xmlns:samlmd="urn:oasis:names:tc:SAML:2.0:metadata"
                   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                   xsi:schemaLocation="urn:mace:shibboleth:2.0:relying-party classpath:/schema/shibboleth-2.0-relying-party.xsd
                                       urn:mace:shibboleth:2.0:relying-party:saml classpath:/schema/shibboleth-2.0-relying-party-saml.xsd
                                       urn:mace:shibboleth:2.0:metadata classpath:/schema/shibboleth-2.0-metadata.xsd
                                       urn:mace:shibboleth:2.0:resource classpath:/schema/shibboleth-2.0-resource.xsd
                                       urn:mace:shibboleth:2.0:security classpath:/schema/shibboleth-2.0-security.xsd
                                       urn:mace:shibboleth:2.0:security:saml classpath:/schema/shibboleth-2.0-security-policy-saml.xsd
                                       urn:oasis:names:tc:SAML:2.0:metadata classpath:/schema/saml-schema-metadata-2.0.xsd">
    <!-- ========================================== -->
    <!--      Relying Party Configurations          -->
    <!-- ========================================== -->
    <rp:AnonymousRelyingParty provider="https://$IDP_HOST/shibboleth"
                           defaultSigningCredentialRef="IdPCredential" />
    <rp:DefaultRelyingParty provider="https://$IDP_HOST/shibboleth"
                         defaultSigningCredentialRef="IdPCredential">
        <!--
            Each attribute in these profiles configuration is set to its default value,
            that is, the values that would be in effect if those attributes were not present.
            We list them here so that people are aware of them (since they seem reluctant to
            read the documentation).
        -->
        <rp:ProfileConfiguration xsi:type="saml:ShibbolethSSOProfile"
                              includeAttributeStatement="false"
                              assertionLifetime="PT5M"
                              signResponses="conditional"
                              signAssertions="never" />
        <rp:ProfileConfiguration xsi:type="saml:SAML1AttributeQueryProfile"
                              assertionLifetime="PT5M"
                              signResponses="conditional"
                              signAssertions="never" />
        <rp:ProfileConfiguration xsi:type="saml:SAML1ArtifactResolutionProfile"
                              signResponses="conditional"
                              signAssertions="never" />
        <rp:ProfileConfiguration xsi:type="saml:SAML2SSOProfile"
                              includeAttributeStatement="true"
                              assertionLifetime="PT5M"
                              assertionProxyCount="0"
                              signResponses="never"
                              signAssertions="always"
                              encryptAssertions="conditional"
                              encryptNameIds="never" />
        <rp:ProfileConfiguration xsi:type="saml:SAML2ECPProfile"
                              includeAttributeStatement="true"
                              assertionLifetime="PT5M"
                              assertionProxyCount="0"
                              signResponses="never"
                              signAssertions="always"
                              encryptAssertions="conditional"
                              encryptNameIds="never" />
        <rp:ProfileConfiguration xsi:type="saml:SAML2AttributeQueryProfile"
                              assertionLifetime="PT5M"
                              assertionProxyCount="0"
                              signResponses="conditional"
                              signAssertions="never"
                              encryptAssertions="conditional"
                              encryptNameIds="never" />
        <rp:ProfileConfiguration xsi:type="saml:SAML2ArtifactResolutionProfile"
                              signResponses="never"
                              signAssertions="always"
                              encryptAssertions="conditional"
                              encryptNameIds="never"/>
    </rp:DefaultRelyingParty>
    <!-- ========================================== -->
    <!--      Metadata Configuration                -->
    <!-- ========================================== -->
    <!-- MetadataProvider the combining other MetadataProviders -->
    <metadata:MetadataProvider id="ShibbolethMetadata" xsi:type="metadata:ChainingMetadataProvider">
        <!-- Load the IdP's own metadata.  This is necessary for artifact support. -->
        <metadata:MetadataProvider id="IdPMD" xsi:type="metadata:ResourceBackedMetadataProvider">
            <metadata:MetadataResource xsi:type="resource:FilesystemResource" file="/opt/shibboleth-idp/metadata/idp-metadata.xml" />
        </metadata:MetadataProvider>
    <!-- Load the SP's metadata.  -->
    <metadata:MetadataProvider xsi:type="FilesystemMetadataProvider" xmlns="urn:mace:shibboleth:2.0:metadata" id="SPMETADATA" metadataFile="/opt/shibboleth-idp/metadata/sp-metadata.xml" />
        <!-- Example metadata provider. -->
        <!-- Reads metadata from a URL and store a backup copy on the file system. -->
        <!-- Validates the signature of the metadata and filters out all by SP entities in order to save memory -->
        <!-- To use: fill in 'metadataURL' and 'backingFile' properties on MetadataResource element -->
        <!--
        <metadata:MetadataProvider id="URLMD" xsi:type="metadata:FileBackedHTTPMetadataProvider"
                          metadataURL="http://example.org/metadata.xml"
                          backingFile="/opt/shibboleth-idp/metadata/some-metadata.xml">
            <metadata:MetadataFilter xsi:type="metadata:ChainingFilter">
                <metadata:MetadataFilter xsi:type="metadata:RequiredValidUntil"
                                maxValidityInterval="P7D" />
                <metadata:MetadataFilter xsi:type="metadata:SignatureValidation"
                                trustEngineRef="shibboleth.MetadataTrustEngine"
                                requireSignedMetadata="true" />
                <metadata:MetadataFilter xsi:type="metadata:EntityRoleWhiteList">
                    <metadata:RetainedRole>samlmd:SPSSODescriptor</metadata:RetainedRole>
                </metadata:MetadataFilter>
            </metadata:MetadataFilter>
        </metadata:MetadataProvider>
        -->
    </metadata:MetadataProvider>
    <!-- ========================================== -->
    <!--     Security Configurations                -->
    <!-- ========================================== -->
    <security:Credential id="IdPCredential" xsi:type="security:X509Filesystem">
        <security:PrivateKey>/opt/shibboleth-idp/credentials/idp-key.pem</security:PrivateKey>
        <security:Certificate>/opt/shibboleth-idp/credentials/idp-cert.pem</security:Certificate>
    </security:Credential>
    <!-- Trust engine used to evaluate the signature on loaded metadata. -->
    <!--
    <security:TrustEngine id="shibboleth.MetadataTrustEngine" xsi:type="security:StaticExplicitKeySignature">
        <security:Credential id="MyFederation1Credentials" xsi:type="security:X509Filesystem">
            <security:Certificate>/opt/shibboleth-idp/credentials/federation1.crt</security:Certificate>
        </security:Credential>
    </security:TrustEngine>
     -->
    <!-- DO NOT EDIT BELOW THIS POINT -->
    <!--
        The following trust engines and rules control every aspect of security related to incoming messages.
        Trust engines evaluate various tokens (like digital signatures) for trust worthiness while the
        security policies establish a set of checks that an incoming message must pass in order to be considered
        secure.  Naturally some of these checks require the validation of the tokens evaluated by the trust
        engines and so you'll see some rules that reference the declared trust engines.
    -->
    <security:TrustEngine id="shibboleth.SignatureTrustEngine" xsi:type="security:SignatureChaining">
        <security:TrustEngine id="shibboleth.SignatureMetadataExplicitKeyTrustEngine" xsi:type="security:MetadataExplicitKeySignature"
                              metadataProviderRef="ShibbolethMetadata" />
        <security:TrustEngine id="shibboleth.SignatureMetadataPKIXTrustEngine" xsi:type="security:MetadataPKIXSignature"
                              metadataProviderRef="ShibbolethMetadata" />
    </security:TrustEngine>
    <security:TrustEngine id="shibboleth.CredentialTrustEngine" xsi:type="security:Chaining">
        <security:TrustEngine id="shibboleth.CredentialMetadataExplictKeyTrustEngine" xsi:type="security:MetadataExplicitKey"
                              metadataProviderRef="ShibbolethMetadata" />
        <security:TrustEngine id="shibboleth.CredentialMetadataPKIXTrustEngine" xsi:type="security:MetadataPKIXX509Credential"
                              metadataProviderRef="ShibbolethMetadata" />
    </security:TrustEngine>
    <security:SecurityPolicy id="shibboleth.ShibbolethSSOSecurityPolicy" xsi:type="security:SecurityPolicyType">
        <security:Rule xsi:type="samlsec:Replay" required="false" />
        <security:Rule xsi:type="samlsec:IssueInstant" required="false"/>
        <security:Rule xsi:type="samlsec:MandatoryIssuer"/>
    </security:SecurityPolicy>
    <security:SecurityPolicy id="shibboleth.SAML1AttributeQuerySecurityPolicy" xsi:type="security:SecurityPolicyType">
        <security:Rule xsi:type="samlsec:Replay"/>
        <security:Rule xsi:type="samlsec:IssueInstant"/>
        <security:Rule xsi:type="samlsec:ProtocolWithXMLSignature" trustEngineRef="shibboleth.SignatureTrustEngine" />
        <security:Rule xsi:type="security:ClientCertAuth" trustEngineRef="shibboleth.CredentialTrustEngine" />
        <security:Rule xsi:type="samlsec:MandatoryIssuer"/>
        <security:Rule xsi:type="security:MandatoryMessageAuthentication" />
    </security:SecurityPolicy>
    <security:SecurityPolicy id="shibboleth.SAML1ArtifactResolutionSecurityPolicy" xsi:type="security:SecurityPolicyType">
        <security:Rule xsi:type="samlsec:Replay"/>
        <security:Rule xsi:type="samlsec:IssueInstant"/>
        <security:Rule xsi:type="samlsec:ProtocolWithXMLSignature" trustEngineRef="shibboleth.SignatureTrustEngine" />
        <security:Rule xsi:type="security:ClientCertAuth" trustEngineRef="shibboleth.CredentialTrustEngine" />
        <security:Rule xsi:type="samlsec:MandatoryIssuer"/>
        <security:Rule xsi:type="security:MandatoryMessageAuthentication" />
    </security:SecurityPolicy>
    <security:SecurityPolicy id="shibboleth.SAML2SSOSecurityPolicy" xsi:type="security:SecurityPolicyType">
        <security:Rule xsi:type="samlsec:Replay"/>
        <security:Rule xsi:type="samlsec:IssueInstant"/>
        <security:Rule xsi:type="samlsec:SAML2AuthnRequestsSigned"/>
        <security:Rule xsi:type="samlsec:ProtocolWithXMLSignature" trustEngineRef="shibboleth.SignatureTrustEngine" />
        <security:Rule xsi:type="samlsec:SAML2HTTPRedirectSimpleSign" trustEngineRef="shibboleth.SignatureTrustEngine" />
        <security:Rule xsi:type="samlsec:SAML2HTTPPostSimpleSign" trustEngineRef="shibboleth.SignatureTrustEngine" />
        <security:Rule xsi:type="samlsec:MandatoryIssuer"/>
    </security:SecurityPolicy>
    <security:SecurityPolicy id="shibboleth.SAML2AttributeQuerySecurityPolicy" xsi:type="security:SecurityPolicyType">
        <security:Rule xsi:type="samlsec:Replay"/>
        <security:Rule xsi:type="samlsec:IssueInstant"/>
        <security:Rule xsi:type="samlsec:ProtocolWithXMLSignature" trustEngineRef="shibboleth.SignatureTrustEngine" />
        <security:Rule xsi:type="samlsec:SAML2HTTPRedirectSimpleSign" trustEngineRef="shibboleth.SignatureTrustEngine" />
        <security:Rule xsi:type="samlsec:SAML2HTTPPostSimpleSign" trustEngineRef="shibboleth.SignatureTrustEngine" />
        <security:Rule xsi:type="security:ClientCertAuth" trustEngineRef="shibboleth.CredentialTrustEngine" />
        <security:Rule xsi:type="samlsec:MandatoryIssuer"/>
        <security:Rule xsi:type="security:MandatoryMessageAuthentication" />
    </security:SecurityPolicy>
    <security:SecurityPolicy id="shibboleth.SAML2ArtifactResolutionSecurityPolicy" xsi:type="security:SecurityPolicyType">
        <security:Rule xsi:type="samlsec:Replay"/>
        <security:Rule xsi:type="samlsec:IssueInstant"/>
        <security:Rule xsi:type="samlsec:ProtocolWithXMLSignature" trustEngineRef="shibboleth.SignatureTrustEngine" />
        <security:Rule xsi:type="samlsec:SAML2HTTPRedirectSimpleSign" trustEngineRef="shibboleth.SignatureTrustEngine" />
        <security:Rule xsi:type="samlsec:SAML2HTTPPostSimpleSign" trustEngineRef="shibboleth.SignatureTrustEngine" />
        <security:Rule xsi:type="security:ClientCertAuth" trustEngineRef="shibboleth.CredentialTrustEngine" />
        <security:Rule xsi:type="samlsec:MandatoryIssuer"/>
        <security:Rule xsi:type="security:MandatoryMessageAuthentication" />
    </security:SecurityPolicy>
    <security:SecurityPolicy id="shibboleth.SAML2SLOSecurityPolicy" xsi:type="security:SecurityPolicyType">
        <security:Rule xsi:type="samlsec:Replay"/>
        <security:Rule xsi:type="samlsec:IssueInstant"/>
        <security:Rule xsi:type="samlsec:ProtocolWithXMLSignature" trustEngineRef="shibboleth.SignatureTrustEngine" />
        <security:Rule xsi:type="samlsec:SAML2HTTPRedirectSimpleSign" trustEngineRef="shibboleth.SignatureTrustEngine" />
        <security:Rule xsi:type="samlsec:SAML2HTTPPostSimpleSign" trustEngineRef="shibboleth.SignatureTrustEngine" />
        <security:Rule xsi:type="security:ClientCertAuth" trustEngineRef="shibboleth.CredentialTrustEngine" />
        <security:Rule xsi:type="samlsec:MandatoryIssuer"/>
        <security:Rule xsi:type="security:MandatoryMessageAuthentication" />
    </security:SecurityPolicy>
</rp:RelyingPartyGroup>
EOF

# mod_shib configuration shib.conf
info "... /etc/httpd/conf.d/shib.conf"
cat << EOF > /etc/httpd/conf.d/shib.conf
# https://wiki.shibboleth.net/confluence/display/SHIB2/NativeSPApacheConfig

# RPM installations on platforms with a conf.d directory will
# result in this file being copied into that directory for you
# and preserved across upgrades.

# For non-RPM installs, you should copy the relevant contents of
# this file to a configuration location you control.

#
# Load the Shibboleth module.
#
LoadModule mod_shib /usr/lib64/shibboleth/mod_shib_22.so

#
# Ensures handler will be accessible.
#
<Location /Shibboleth.sso>
  Satisfy Any
  Allow from all
</Location>

#
# Used for example style sheet in error templates.
#
<IfModule mod_alias.c>
  <Location /shibboleth-sp>
    Satisfy Any
    Allow from all
  </Location>
  Alias /shibboleth-sp/main.css /usr/share/shibboleth/main.css
</IfModule>

#
# Configure the module for content.
#
# You MUST enable AuthType shibboleth for the module to process
# any requests, and there MUST be a require command as well. To
# enable Shibboleth but not specify any session/access requirements
# use "require shibboleth".
#
<Location $PROTECTED_DIR>
  AuthType shibboleth
  ShibRequestSetting requireSession 1
  require valid-user
</Location>
EOF

# Restart the shibboleth daemon
service shibd stop
`dirname $0`/setup_https.sh "$SP_CERT_FILE" "$SP_KEY_FILE" "$SP_CERT_CA_FILE" "$SP_CERT_CHAIN_FILE"
service shibd start

info "Done installing Shibboleth"
