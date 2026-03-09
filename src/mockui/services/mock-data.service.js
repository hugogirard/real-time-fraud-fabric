/**
 * MockDataService
 * ----------------
 * Simulates backend API calls for authentication, chat sessions,
 * and fraud-alert chatbot interactions.
 *
 * When migrating to Angular, convert this to an injectable service
 * (e.g. @Injectable ChatService / AuthService) and replace
 * setTimeout with HttpClient observables.
 */

const MockDataService = (() => {
  // ---------- Mock Data ----------

  const users = [
    { id: "u1", username: "john.doe", password: "Pass1234!", fullName: "John Doe", cardLast4: "4921" },
    { id: "u2", username: "jane.smith", password: "Pass1234!", fullName: "Jane Smith", cardLast4: "8834" }
  ];

  const chatSessions = {
    u1: [
      {
        id: "s1",
        title: "Fraud Alert – $249.99 at ElectroMart",
        date: "2026-03-07T14:32:00Z",
        status: "resolved",
        messages: [
          { id: "m1", role: "bot", text: "Hello John, we detected a suspicious transaction of **$249.99** at ElectroMart on your card ending in 4921. Did you authorize this transaction?", timestamp: "2026-03-07T14:32:00Z" },
          { id: "m2", role: "user", text: "No, I didn't make that purchase.", timestamp: "2026-03-07T14:32:45Z" },
          { id: "m3", role: "bot", text: "Thank you for confirming. We have temporarily blocked your card ending in 4921 and flagged this transaction for investigation. A new card will be shipped to your registered address within 3-5 business days.", timestamp: "2026-03-07T14:33:00Z" },
          { id: "m4", role: "user", text: "Okay, thank you for the quick response.", timestamp: "2026-03-07T14:33:30Z" },
          { id: "m5", role: "bot", text: "You're welcome! Your case reference is **#FR-20260307-001**. Is there anything else I can help you with?", timestamp: "2026-03-07T14:33:45Z" },
          { id: "m6", role: "user", text: "No, that's all.", timestamp: "2026-03-07T14:34:00Z" },
          { id: "m7", role: "bot", text: "Thank you, John. Stay safe! This session is now resolved.", timestamp: "2026-03-07T14:34:15Z" }
        ]
      },
      {
        id: "s2",
        title: "Fraud Alert – $89.00 at TravelBooker",
        date: "2026-03-05T09:15:00Z",
        status: "resolved",
        messages: [
          { id: "m1", role: "bot", text: "Hi John, we noticed a charge of **$89.00** from TravelBooker on your card ending in 4921. Was this you?", timestamp: "2026-03-05T09:15:00Z" },
          { id: "m2", role: "user", text: "Yes, that was me. I booked a bus ticket.", timestamp: "2026-03-05T09:16:00Z" },
          { id: "m3", role: "bot", text: "Great, thanks for confirming! We've marked this transaction as legitimate. No further action is needed.", timestamp: "2026-03-05T09:16:30Z" }
        ]
      },
      {
        id: "s3",
        title: "Fraud Alert – $1,200.00 at LuxuryWatches.com",
        date: "2026-02-28T18:45:00Z",
        status: "resolved",
        messages: [
          { id: "m1", role: "bot", text: "Hello John, a high-value transaction of **$1,200.00** was attempted at LuxuryWatches.com using your card ending in 4921. Did you authorize this?", timestamp: "2026-02-28T18:45:00Z" },
          { id: "m2", role: "user", text: "Absolutely not! I never shop there.", timestamp: "2026-02-28T18:46:00Z" },
          { id: "m3", role: "bot", text: "The transaction has been **declined and blocked**. We are initiating a fraud investigation. Your card has been temporarily frozen. Would you like us to issue a replacement card?", timestamp: "2026-02-28T18:46:30Z" },
          { id: "m4", role: "user", text: "Yes, please send a new one.", timestamp: "2026-02-28T18:47:00Z" },
          { id: "m5", role: "bot", text: "Done! A new card will arrive in 3-5 business days. Case reference: **#FR-20260228-004**. Anything else?", timestamp: "2026-02-28T18:47:30Z" },
          { id: "m6", role: "user", text: "No thanks.", timestamp: "2026-02-28T18:48:00Z" },
          { id: "m7", role: "bot", text: "Stay vigilant, John. We're here 24/7 if you need us!", timestamp: "2026-02-28T18:48:15Z" }
        ]
      }
    ],
    u2: [
      {
        id: "s4",
        title: "Fraud Alert – $54.30 at QuickGas Station",
        date: "2026-03-08T11:20:00Z",
        status: "active",
        messages: [
          { id: "m1", role: "bot", text: "Hello Jane, we flagged a transaction of **$54.30** at QuickGas Station on your card ending in 8834. Did you authorize this?", timestamp: "2026-03-08T11:20:00Z" },
          { id: "m2", role: "user", text: "Hmm, I'm not sure. Let me check.", timestamp: "2026-03-08T11:21:00Z" },
          { id: "m3", role: "bot", text: "Take your time. Your card is temporarily on hold as a precaution. Just let me know when you've confirmed.", timestamp: "2026-03-08T11:21:30Z" }
        ]
      }
    ]
  };

  // Bot response templates for new messages
  const botResponses = [
    "Thank you for that information. Let me look into this for you right away.",
    "I understand your concern. We take fraud very seriously at Contoso Bank. Let me check the details.",
    "I've flagged this for our fraud investigation team. You should hear back within 24 hours.",
    "Your card has been secured. No further unauthorized transactions can be made.",
    "I've updated your case file. Is there anything else you'd like to know?",
    "For your security, I recommend changing your online banking password as well.",
    "A provisional credit has been applied to your account while we investigate.",
    "Our records show this merchant has been flagged before. We're escalating this case."
  ];

  let currentUser = null;
  let responseIndex = 0;

  // ---------- Simulated API Delay ----------

  function simulateDelay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  // ---------- Auth Service ----------

  async function login(username, password) {
    await simulateDelay(800);
    const user = users.find(u => u.username === username && u.password === password);
    if (!user) {
      return { success: false, error: "Invalid username or password." };
    }
    currentUser = user;
    return { success: true, user: { id: user.id, fullName: user.fullName, cardLast4: user.cardLast4 } };
  }

  async function logout() {
    await simulateDelay(300);
    currentUser = null;
    return { success: true };
  }

  function getCurrentUser() {
    return currentUser
      ? { id: currentUser.id, fullName: currentUser.fullName, cardLast4: currentUser.cardLast4 }
      : null;
  }

  // ---------- Chat Session Service ----------

  async function getChatSessions() {
    await simulateDelay(500);
    if (!currentUser) return { success: false, error: "Not authenticated." };
    const sessions = chatSessions[currentUser.id] || [];
    return {
      success: true,
      sessions: sessions.map(s => ({
        id: s.id,
        title: s.title,
        date: s.date,
        status: s.status,
        messageCount: s.messages.length
      }))
    };
  }

  async function getChatMessages(sessionId) {
    await simulateDelay(400);
    if (!currentUser) return { success: false, error: "Not authenticated." };
    const sessions = chatSessions[currentUser.id] || [];
    const session = sessions.find(s => s.id === sessionId);
    if (!session) return { success: false, error: "Session not found." };
    return { success: true, session: { ...session } };
  }

  async function sendMessage(sessionId, text) {
    await simulateDelay(1000);
    if (!currentUser) return { success: false, error: "Not authenticated." };
    const sessions = chatSessions[currentUser.id] || [];
    const session = sessions.find(s => s.id === sessionId);
    if (!session) return { success: false, error: "Session not found." };

    const userMsg = {
      id: `m${Date.now()}`,
      role: "user",
      text: text,
      timestamp: new Date().toISOString()
    };
    session.messages.push(userMsg);

    // Simulate bot reply
    const botReply = {
      id: `m${Date.now() + 1}`,
      role: "bot",
      text: botResponses[responseIndex % botResponses.length],
      timestamp: new Date(Date.now() + 1500).toISOString()
    };
    responseIndex++;
    session.messages.push(botReply);

    return { success: true, userMessage: userMsg, botMessage: botReply };
  }

  async function createNewSession(alertTitle) {
    await simulateDelay(600);
    if (!currentUser) return { success: false, error: "Not authenticated." };

    const newSession = {
      id: `s${Date.now()}`,
      title: alertTitle || "New Fraud Alert",
      date: new Date().toISOString(),
      status: "active",
      messages: [
        {
          id: `m${Date.now()}`,
          role: "bot",
          text: `Hello ${currentUser.fullName.split(" ")[0]}, a new fraud alert has been raised on your card ending in ${currentUser.cardLast4}. How can I assist you?`,
          timestamp: new Date().toISOString()
        }
      ]
    };

    if (!chatSessions[currentUser.id]) {
      chatSessions[currentUser.id] = [];
    }
    chatSessions[currentUser.id].unshift(newSession);

    return {
      success: true,
      session: {
        id: newSession.id,
        title: newSession.title,
        date: newSession.date,
        status: newSession.status,
        messageCount: newSession.messages.length
      }
    };
  }

  // ---------- Public API ----------

  return {
    login,
    logout,
    getCurrentUser,
    getChatSessions,
    getChatMessages,
    sendMessage,
    createNewSession
  };
})();
