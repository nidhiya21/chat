<!--- Param the url value. --->
<cfparam name="url.userID" type="string" default="" />
<cfparam name="url.handle" type="string" default="" />
<cfparam name="url.message" type="string" default="" />


<!---
	Pusher information used to tie this push notification
	to a given application and to a given client (listening
	for a given channel).
	NOTE: Your Pusher account can have multiple applications
	associated with it (each of which can have on-the-fly
	channel creation).
--->
<cfset pusherAppID = "1353" />
<cfset pusherKey = "ceef7621b815dc2a7c9f" /> 
<cfset pusherSecret = "****************" />
<cfset pusherChannel = "chatRoom" />

<!---
	Event we are triggering (this is what the client will
	"bind" to on the given channel).
--->
<cfset pusherEvent = "messageEvent" />

<!---
	At this point, we have to assemble the data we are going to
	push using Pusher. We need to create a chat data struct with
	the passed-in data.
	NOTE: We are using the array-notation to ensure the case of
	the keys is maintained. This is because we have to pass this
	off to Javascript which is case-sensitive.
--->
<cfset chatData = {} />
<cfset chatData[ "userID" ] = url.userID />
<cfset chatData[ "handle" ] = htmlEditFormat( url.handle ) />
<cfset chatData[ "message" ] = htmlEditFormat( url.message ) />

<!---
	Now that we have our chat data, we have to serialize it for
	our HTTP POST to the Pusher App. All values "pushed" must be
	in JSON format.
--->
<cfset pusherData = serializeJSON( chatData ) />

<!--- Authentication information. --->
<cfset authVersion = "1.0" />
<cfset authMD5Body = lcase( hash( pusherData, "md5" ) ) />
<cfset authTimeStamp = fix( getTickCount() / 1000 ) />

<!--- Build the post resource (the RESTfule resource). --->
<cfset pusherResource = "/apps/#pusherAppID#/channels/#pusherChannel#/events" />


<!--- ------------------------------------------------- --->
<!--- ------------------------------------------------- --->


<!---
	The following is the digital signing of the HTTP request.
	Frankly, this stuff is pretty far above my understanding
	of cryptology. I have adapted code from the PusherApp
	ColdFusion component written by Bradley Lambert:
	http://github.com/blambert/pusher-cfc
--->


<!---
	Create the list of query string values (alpha-sorted with no
	URL encoding).
--->
<cfsavecontent variable="queryStringData">
	<cfoutput>
		auth_key=#pusherKey#
		auth_timestamp=#authTimeStamp#
		auth_version=#authVersion#
		body_md5=#authMD5Body#
		name=#pusherEvent#
	</cfoutput>
</cfsavecontent>

<!---
	Create the raw signature data. This is the HTTP
	method, the resource, and the alpha-ordered query
	string (non-URL-encoded values).
--->
<cfset signatureData = (
	("POST" & chr( 10 )) &
	(pusherResource & chr( 10 )) &
	reReplace(
		trim( queryStringData ),
		"\s+",
		"&",
		"all"
		)
	) />

<!---
	Create our secret key generator. This can create a secret
	key from a given byte array. Initialize it with the byte
	array version of our PushApp secret key and the algorithm
	we want to use to generate the secret key.
--->
<cfset secretKeySpec = createObject(
	"java",
	"javax.crypto.spec.SecretKeySpec"
	).init(
		toBinary( toBase64( pusherSecret ) ),
		"HmacSHA256"
		)
	/>

<!---
	Create our MAC (Message Authentication Code) generator
	to encrypt the message data using the PusherApp shared
	secret key.
--->
<cfset mac = createObject( "java", "javax.crypto.Mac" )
	.getInstance( "HmacSHA256" )
	/>

<!--- Initialize the MAC instance using our secret key. --->
<cfset mac.init( secretKeySpec ) />

<!---
	Complete the mac operation, encrypting the given secret
	key (that we created above).
--->
<cfset encryptedBytes = mac.doFinal( signatureData.getBytes() ) />


<!---
	Now that we have the encrypted data, we have to convert
	that data to a HEX-encoded string. We will use the big
	integer for this.
--->
<cfset bigInt = createObject( "java", "java.math.BigInteger" )
	.init( 1, encryptedBytes )
	/>

<!--- Convert the encrypted bytes to the HEX string. --->
<cfset secureSignature = bigInt.toString(16) />

<!---
	Apparently, we need to make sure the signature is at least
	32 characters long. As such, let's just left-pad with spaces
	and then replace with zeroes.
--->
<cfset secureSignature = replace(
	lJustify( secureSignature, 32 ),
	" ",
	"0",
	"all"
	) />


<!--- ----------------------------------------------------- --->
<!--- ----------------------------------------------------- --->


<!---
	Now that we have all the values we want to post, including
	our encrypted signature, we can post to the PusherApp REST
	web service using CFHTTP.
--->
<cfhttp
	result="post"
	method="post"
	url="http://api.pusherapp.com#pusherResource#">

	<!---
		Alert the post resource that the value is coming through
		as JSON data.
	--->
	<cfhttpparam
		type="header"
		name="content-type"
		value="application/json"
		/>

	<!--- Set the authorization parameters. --->

	<cfhttpparam
		type="url"
		name="auth_version"
		value="#authVersion#"
		/>

	<cfhttpparam
		type="url"
		name="auth_key"
		value="#pusherKey#"
		/>

	<cfhttpparam
		type="url"
		name="auth_timestamp"
		value="#authTimeStamp#"
		/>

		<cfhttpparam
		type="url"
		name="body_md5"
		value="#authMD5Body#"
		/>

	<!--- Sent the name of the pusher event. --->
	<cfhttpparam
		type="url"
		name="name"
		value="#pusherEvent#"
		/>

	<!--- Send the actual message data (JSON data). --->
	<cfhttpparam
		type="body"
		value="#pusherData#"
		/>

	<!--- Digitally sign the HTTP request. --->
	<cfhttpparam
		type="url"
		name="auth_signature"
		value="#secureSignature#"
		/>

</cfhttp>


<!--- Push a success! --->
<cfcontent
	type="text/plain"
	variable="#toBinary( toBase64( 'success' ) )#"
	/>