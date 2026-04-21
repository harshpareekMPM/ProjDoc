importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyD7pGo8YNzYfB_4YpX08WFPI2QxoCncZ3c",
  authDomain: "projdoc-aab8e.firebaseapp.com",
  projectId: "projdoc-aab8e",
  storageBucket: "projdoc-aab8e.firebasestorage.app",
  messagingSenderId: "891569494592",
  appId: "1:891569494592:web:dfd25b7c827607cef41da5",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const { title, body } = payload.notification ?? {};
  self.registration.showNotification(title ?? "ProjectDocs AI", {
    body: body ?? "",
    icon: "/icons/Icon-192.png",
  });
});
