const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Firestore path where you store connections:
// users/{userId}/connections/{otherUid}
//
// We will send a push when status == "requested"
// (i.e., someone requested to connect with this user)
exports.onConnectionWrite = functions.firestore
  .document('users/{userId}/connections/{otherUid}')
  .onWrite(async (change, context) => {
    const afterData = change.after.exists ? change.after.data() : null;
    const beforeData = change.before.exists ? change.before.data() : null;

    if (!afterData) {
      // document deleted, ignore
      return null;
    }

    const status = afterData.status;
    const prevStatus = beforeData ? beforeData.status : null;

    // If status didn’t change, do nothing
    if (status === prevStatus) return null;

    const targetUid = context.params.userId;   // who owns this connections subcollection
    const otherUid = context.params.otherUid; // the other player

    // When this user receives a request → status "requested"
    if (status === 'requested') {
      try {
        // Load target user to get their FCM token
        const targetDoc = await admin.firestore()
          .collection('users')
          .doc(targetUid)
          .get();

        if (!targetDoc.exists) return null;

        const targetData = targetDoc.data() || {};
        const targetToken = targetData.fcmToken;

        if (!targetToken) {
          console.log('No fcmToken for user', targetUid);
          return null;
        }

        // Load sender user to show name in notification
        const otherDoc = await admin.firestore()
          .collection('users')
          .doc(otherUid)
          .get();

        const otherData = otherDoc.data() || {};
        const fromName = otherData.username || 'A player';

        const message = {
          token: targetToken,
          notification: {
            title: 'New connection request',
            body: `${fromName} wants to connect with you`,
          },
          android: {
            priority: 'high',
            notification: {
              channelId: 'kritun_default_channel', // 👈 matches main.dart + AndroidManifest
              sound: 'default',
            },
          },
          data: {
            type: 'connection_request',
            fromUid: otherUid,
          },
        };

        await admin.messaging().send(message);
        console.log('Connection request notification sent to', targetUid);

      } catch (e) {
        console.error('Error sending connection request notification:', e);
      }
    }

    // You can also handle "connected" status to notify both users:
    if (status === 'connected' && prevStatus !== 'connected') {
      // Optional: send "You are now connected" push – can add similar code here.
    }

    return null;
  });
