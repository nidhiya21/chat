<!DOCTYPE HTML>
<html>
<head>
	<title>Pusher And ColdFusion Powered Chat</title>
	<style type="text/css">
		form {
			width: 500px ;
			}
		#chatLog {
			background-color: #FAFAFA ;
			border: 1px solid #D0D0D0 ;
			height: 200px ;
			margin-bottom: 10px ;
			overflow-x: hidden ;
			overflow-y: scroll ;
			padding: 10px 10px 10px 10px ;
			width: 480px ;
			}
		#handle {
			float: left ;
			margin-bottom: 5px ;
			}
		#handleLabel {
			font-weight: bold ;
			}
		#handleTools {
			font-size: 90% ;
			font-style: italic ;
			}
		#handleTools a {
			color: #333333 ;
			}
		#typeNote {
			color: #999999 ;
			display: none ;
			float: right ;
			font-style: italic ;
			}
		#message {
			clear: both ;
			font-size: 16px ;
			width: 420px ;
			}
		#submit {
			font-size: 16px ;
			width: 70px ;
			}
		div.chatItem {
			border-bottom: 1px solid #F0F0F0 ;
			margin: 0px 0px 3px 0px ;
			padding: 0px 0px 3px 0px ;
			}
		div.chatItem span.handle {
			color: blue ;
			font-weight: bold ;
			}
		div.myChatItem span.handle {
			color: red ;
			}
	</style>

    <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.6.0/jquery.min.js"></script>
	<script type="text/javascript" src="http://js.pusherapp.com/1.4/pusher.min.js"></script>
	<script type="text/javascript">
		// This is for compatability with browsers that don't yet
		// support Web Sockets, but DO support Flash.
		//
		// NOTE: This SWF can be downloaded from the PusherApp
		// website. It is a Flash proxy to the standard Web
		// Sockets interface.
		WebSocket.__swfLocation = "./WebSocketMain.swf";
		// When the DOM is ready, init the scripts.
		$(function(){
			// This is the user ID. This allows us to track the user
			// outside the context of the handle.
			<cfoutput>
				var userID = "#createUUID()#";
			</cfoutput>
			// Create a Pusher server object with your app's key and
			// the channel you want to listen on. Channels are unique
			// to your application.
			var server = new Pusher(
				"ceef7621b815dc2a7c9f",
				"chatRoom"
			);
			// Get references to our DOM elements.
			var form = $( "form" );
			var chatLog = $( "#chatLog" );
			var handleLabel = $( "#handleLabel" );
			var handleToggle = $( "#handleTools a" );
			var typeNote = $( "#typeNote" );
			var typeLabel = $( "#typeLabel" );
			var message = $( "#message" );
			// Allow the changing of the handle.
			handleToggle
				.attr( "href", "javascript:void( 0 )" )
				.click(
					function( event ){
						// Prevent default click.
						event.preventDefault();
						// Prompt user for new name.
						handleLabel.text(
							prompt( "New Handle:", handleLabel.text() )
						);
						// Refocus the messsage box so the user can
						// start typing again.
						message.focus();
					}
				)
			;
			// Bind to the form submission to send the message to the
			// ColdFusion server (to be pushed to all clients).
			form.submit(
				function( event ){
					// Prevent the default events since we don't want
					// the page to refresh.
					event.preventDefault();
					// Check to see if we have a message. If there is
					// no message, don't hit the server.
					if (!message.val().length){
						return;
					}
					// Send the message to the server.
					$.get(
						"./send.cfm",
						{
							userID: userID,
							handle: handleLabel.text(),
							message: message.val()
						},
						function(){
							// Clear the message and refocus it.
							message
								.val( "" )
								.focus()
							;
						}
					);
					// Clear any "stop" timer for typing. If the
					// user has submitted the message then we can
					// assume they are done typing this message.
					clearTimeout( message.data( "timer" ) );
					// Flag that the user is no longer typing a
					// message.
					message.data( "isTyping", false );
					// Tell the server that this user has stopped
					// typing.
					$.get(
						"./type.cfm",
						{
							userID: userID,
							handle: handleLabel.text(),
							isTyping: false
						}
					);
				}
			);
			// Bind the message input so that we can see when the
			// user starts typing (and we can alert the server).
			message.keydown(
				function( event ){
					// Clear any "stop" timer for typing. This way,
					// the previous stop event doesn't get triggered
					// while the user has continued to type.
					clearTimeout( message.data( "timer" ) );
					// Check to see if the user is currently typing.
					// If they are, then we don't need to do any of
					// this stuff until they stop.
					if (message.data( "isTyping" )){
						return;
					}
					// At this point, we know the user was not
					// previously typing so we can send the request
					// to the server that the user has started.
					message.data( "isTyping", true );
					// Tell the server that this user is typing.
					$.get(
						"./type.cfm",
						{
							userID: userID,
							handle: handleLabel.text(),
							isTyping: true
						}
					);
				}
			);
			// Bind to the message input so that we can see when the
			// users stops typing (and we can alert the server).
			message.keyup(
				function( event ){
					// Clear any "stop" timer for typing. We need to
					// clear here as well because it looks like the
					// browser has trouble trapping every single
					// individual key as a different typing event
					// (at least, that's what I think is going on).
					clearTimeout( message.data( "timer" ) );
					// The key up event doesn't mean that the user
					// has stopped typing. But, it does give us a
					// reason to start paying attention. Let's check
					// back shortly.
					message.data(
						"timer",
						setTimeout(
							function(){
								// Flag that the user is no longer
								// typing a message.
								message.data( "isTyping", false );
								// Tell the server that this user
								// has stopped typing.
								$.get(
									"./type.cfm",
									{
										userID: userID,
										handle: handleLabel.text(),
										isTyping: false
									}
								);
							},
							750
						)
					);
				}
			);
			// Now that we have the pusher connection for a given
			// channel, we want to listen for certain events to come
			// over that channel (chat messages).
			server.bind(
				"messageEvent",
				function( chatData ) {
					// Append the chat item to the chat log. That
					// chatData is a Javascript object with the
					// message meta data.
					var chatItem = $(
						"<div class='chatItem'>" +
							"<span class='handle'>" +
								chatData.handle +
							"</span>: " +
							"<span class='message'>" +
								chatData.message +
							"</span>" +
						"</div>"
					);
					// Check to see if the chat item is "mine" or
					// if it someone else's/
					if (chatData.userID == userID){
						// Add the "mine" item.
						chatItem.addClass( "myChatItem" );
					}
					// Append the chat item to the chat log.
					chatLog.append( chatItem );
					// Scroll the chat item to the bottom.
					chatLog.scrollTop( chatLog.outerHeight() );
				}
			);
			// Let's also bind to the pusher connection for the the
			// type event so that we can see when given people start
			// and stop typing.
			server.bind(
				"typeEvent",
				function( typeData ){
					// First, check to see if this is an event for
					// THIS user. If so, we can ignore it.
					if (typeData.userID == userID){
						return;
					}
					// Now, check to see if the event is a start
					// event. This will take presendence over the
					// stop event for visual display.
					if (typeData.isTyping){
						// Set the typing label.
						typeLabel.text( typeData.handle );
						// Set the REL attribute.
						typeLabel.attr( "rel", typeData.userID );
						// Show the label.
						typeNote.show();
					// If it's a stop event, we only care if the stop
					// event is corresponding to the most current
					// start event (otherwise, we've already lost the
					// opportunity for that one).
					} else if (typeLabel.attr( "rel" ) == typeData.userID){
						// Hide the note.
						typeNote.hide();
					}
				}
			);
		});
	</script>
</head>
<body>

	<h1>
		Pusher And ColdFusion Powered Chat
	</h1>

	<form>

		<div id="chatLog">
			<!--- To be populated dynamically. --->
		</div>

		<div id="handle">
			<span id="handleLabel">RandomDude</span>
			<span id="handleTools">( <a>Change Handle</a> )</span>
		</div>

		<div id="typeNote">
			<span id="typeLabel" rel="">Unknown</span> is typing.
		</div>

		<div id="messageTools">
			<input id="message" type="text" name="message" />
			<input id="submit" type="submit" value="SEND" />
		</div>

	</form>

</body>
</html>