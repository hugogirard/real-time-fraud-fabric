/**
 * Contoso Bank – Fraud Alert Assistant
 * Main application controller (vanilla JS).
 *
 * When migrating to Angular, split this into:
 *   - LoginComponent
 *   - SidebarComponent
 *   - ChatbotComponent
 *   - ChatInputComponent
 *   - MessageComponent
 *   - AuthService (wrapping MockDataService.login/logout)
 *   - ChatService (wrapping MockDataService.getChatSessions/sendMessage/etc.)
 *   - AuthGuard (route guard for /chat)
 */

document.addEventListener("DOMContentLoaded", () => {
  // ========== DOM References ==========

  // Pages
  const loginPage = document.getElementById("login-page");
  const chatPage = document.getElementById("chat-page");

  // Login
  const loginBtn = document.getElementById("login-btn");
  const loginBtnText = document.getElementById("login-btn-text");
  const loginSpinner = document.getElementById("login-spinner");
  const loginError = document.getElementById("login-error");
  const loginErrorText = document.getElementById("login-error-text");

  // Sidebar
  const sessionList = document.getElementById("session-items");
  const sidebarLoading = document.getElementById("sidebar-loading");
  const sidebarEmpty = document.getElementById("sidebar-empty");
  const newChatBtn = document.getElementById("new-chat-btn");
  const logoutBtn = document.getElementById("logout-btn");
  const userAvatar = document.getElementById("user-avatar");
  const userName = document.getElementById("user-name");
  const userCard = document.getElementById("user-card");

  // Chat
  const chatTitle = document.getElementById("chat-title");
  const chatStatusBadge = document.getElementById("chat-status-badge");
  const chatMessages = document.getElementById("chat-messages");
  const messageListEl = document.getElementById("message-list");
  const chatWelcome = document.getElementById("chat-welcome");
  const typingIndicator = document.getElementById("typing-indicator");
  const chatInputArea = document.getElementById("chat-input-area");
  const chatInput = document.getElementById("chat-input");
  const sendBtn = document.getElementById("send-btn");

  // ========== State ==========
  let activeSessionId = null;

  // ========== Helpers ==========

  function formatDate(isoStr) {
    const d = new Date(isoStr);
    const now = new Date();
    const diffMs = now - d;
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffDays === 0) return "Today";
    if (diffDays === 1) return "Yesterday";
    if (diffDays < 7) return `${diffDays} days ago`;
    return d.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
  }

  function formatTime(isoStr) {
    return new Date(isoStr).toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit" });
  }

  function getInitials(name) {
    return name.split(" ").map(n => n[0]).join("").toUpperCase();
  }

  /** Simple markdown bold **text** → <strong>text</strong> */
  function renderBoldMarkdown(text) {
    const div = document.createElement("div");
    // Split on **...** patterns and build safely
    const parts = text.split(/\*\*(.*?)\*\*/g);
    parts.forEach((part, i) => {
      if (i % 2 === 1) {
        const strong = document.createElement("strong");
        strong.textContent = part;
        div.appendChild(strong);
      } else {
        div.appendChild(document.createTextNode(part));
      }
    });
    return div.innerHTML;
  }

  function scrollToBottom() {
    chatMessages.scrollTop = chatMessages.scrollHeight;
  }

  // ========== Login (Entra ID – simulated) ==========

  loginBtn.addEventListener("click", async () => {
    loginError.classList.remove("visible");
    loginBtn.disabled = true;
    loginBtnText.textContent = "Signing in…";
    loginSpinner.classList.add("visible");

    // Simulate Entra ID redirect/token exchange – auto-login as john.doe
    const result = await MockDataService.login("john.doe", "Pass1234!");

    loginBtn.disabled = false;
    loginBtnText.textContent = "Sign in with Microsoft";
    loginSpinner.classList.remove("visible");

    if (!result.success) {
      loginErrorText.textContent = result.error;
      loginError.classList.add("visible");
      return;
    }

    // Transition to chat
    showChatPage(result.user);
  });

  // ========== Logout ==========

  logoutBtn.addEventListener("click", async () => {
    await MockDataService.logout();
    activeSessionId = null;
    chatPage.classList.add("hidden");
    loginPage.classList.remove("hidden");
    loginError.classList.remove("visible");
  });

  // ========== Show Chat Page ==========

  async function showChatPage(user) {
    loginPage.classList.add("hidden");
    chatPage.classList.remove("hidden");

    // Set user info
    userAvatar.textContent = getInitials(user.fullName);
    userName.textContent = user.fullName;
    userCard.textContent = `Card •••• ${user.cardLast4}`;

    // Reset chat area
    resetChatArea();

    // Load sessions
    await loadSessions();

    // Auto-open a new fraud alert so user lands in a conversation
    const newSession = await MockDataService.createNewSession("Fraud Alert – $352.00 at GlobalShop Online");
    if (newSession.success) {
      await loadSessions();
      await openSession(newSession.session.id);
    }
  }

  // ========== Session List ==========

  async function loadSessions() {
    sidebarLoading.classList.remove("hidden");
    sidebarEmpty.classList.add("hidden");
    sessionList.innerHTML = "";

    const result = await MockDataService.getChatSessions();

    sidebarLoading.classList.add("hidden");

    if (!result.success || result.sessions.length === 0) {
      sidebarEmpty.classList.remove("hidden");
      return;
    }

    // Group by date
    const activeSessions = result.sessions.filter(s => s.status === "active");
    const resolvedSessions = result.sessions.filter(s => s.status === "resolved");

    if (activeSessions.length > 0) {
      appendSectionLabel("Active Alerts");
      activeSessions.forEach(s => appendSessionItem(s));
    }

    if (resolvedSessions.length > 0) {
      appendSectionLabel("Resolved");
      resolvedSessions.forEach(s => appendSessionItem(s));
    }
  }

  function appendSectionLabel(text) {
    const el = document.createElement("div");
    el.className = "sidebar-section-label";
    el.textContent = text;
    sessionList.appendChild(el);
  }

  function appendSessionItem(session) {
    const el = document.createElement("div");
    el.className = "session-item";
    el.dataset.sessionId = session.id;

    if (session.id === activeSessionId) {
      el.classList.add("active");
    }

    const isActive = session.status === "active";
    const iconClass = isActive ? "status-active" : "status-resolved";
    const iconSvg = isActive
      ? '<svg viewBox="0 0 16 16" fill="currentColor"><path d="M8 1a7 7 0 100 14A7 7 0 008 1zm-.5 3.5h1v5h-1v-5zm.5 7.5a.75.75 0 110-1.5.75.75 0 010 1.5z"/></svg>'
      : '<svg viewBox="0 0 16 16" fill="currentColor"><path d="M8 1a7 7 0 100 14A7 7 0 008 1zm3.354 5.354l-4 4a.5.5 0 01-.708 0l-2-2a.5.5 0 11.708-.708L7 9.293l3.646-3.647a.5.5 0 11.708.708z"/></svg>';

    el.innerHTML = `
      <div class="session-icon ${iconClass}">${iconSvg}</div>
      <div class="session-info">
        <div class="session-title" title="${escapeAttr(session.title)}">${escapeHtml(session.title)}</div>
        <div class="session-meta">
          <span class="session-date">${formatDate(session.date)}</span>
          <span class="badge ${isActive ? 'badge-active' : 'badge-resolved'}">${session.status}</span>
        </div>
      </div>
    `;

    el.addEventListener("click", () => openSession(session.id));
    sessionList.appendChild(el);
  }

  function escapeHtml(str) {
    const div = document.createElement("div");
    div.textContent = str;
    return div.innerHTML;
  }

  function escapeAttr(str) {
    return str.replace(/"/g, "&quot;").replace(/'/g, "&#39;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }

  // ========== Open Session ==========

  async function openSession(sessionId) {
    activeSessionId = sessionId;

    // Highlight active
    document.querySelectorAll(".session-item").forEach(el => {
      el.classList.toggle("active", el.dataset.sessionId === sessionId);
    });

    // Show loading
    chatWelcome.classList.add("hidden");
    messageListEl.innerHTML = '<div class="chat-loading"><span class="spinner"></span> Loading messages…</div>';
    chatInputArea.classList.add("hidden");

    const result = await MockDataService.getChatMessages(sessionId);

    if (!result.success) return;

    const session = result.session;

    // Update header
    chatTitle.textContent = session.title;
    chatStatusBadge.innerHTML = `<span class="badge ${session.status === 'active' ? 'badge-active' : 'badge-resolved'}">${session.status}</span>`;

    // Render messages
    messageListEl.innerHTML = "";
    session.messages.forEach(msg => appendMessage(msg));

    // Show input if session is active
    if (session.status === "active") {
      chatInputArea.classList.remove("hidden");
    } else {
      chatInputArea.classList.add("hidden");
    }

    scrollToBottom();
  }

  function appendMessage(msg) {
    const user = MockDataService.getCurrentUser();
    const isUser = msg.role === "user";

    const el = document.createElement("div");
    el.className = `message ${msg.role}`;

    const avatarText = isUser ? getInitials(user.fullName) : "CB";

    el.innerHTML = `
      <div class="message-avatar">${escapeHtml(avatarText)}</div>
      <div class="message-content">
        <div class="message-bubble">${renderBoldMarkdown(msg.text)}</div>
        <span class="message-time">${formatTime(msg.timestamp)}</span>
      </div>
    `;

    messageListEl.appendChild(el);
  }

  function resetChatArea() {
    activeSessionId = null;
    chatTitle.textContent = "Select a conversation";
    chatStatusBadge.innerHTML = "";
    messageListEl.innerHTML = "";
    chatWelcome.classList.remove("hidden");
    chatInputArea.classList.add("hidden");
    chatInput.value = "";
    sendBtn.disabled = true;
  }

  // ========== Send Message ==========

  chatInput.addEventListener("input", () => {
    sendBtn.disabled = chatInput.value.trim().length === 0;
    // Auto-resize
    chatInput.style.height = "auto";
    chatInput.style.height = Math.min(chatInput.scrollHeight, 120) + "px";
  });

  chatInput.addEventListener("keydown", (e) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      if (!sendBtn.disabled) sendMessage();
    }
  });

  sendBtn.addEventListener("click", sendMessage);

  async function sendMessage() {
    const text = chatInput.value.trim();
    if (!text || !activeSessionId) return;

    // Clear input
    chatInput.value = "";
    chatInput.style.height = "auto";
    sendBtn.disabled = true;

    // Optimistically show user message
    const user = MockDataService.getCurrentUser();
    appendMessage({
      role: "user",
      text: text,
      timestamp: new Date().toISOString()
    });
    scrollToBottom();

    // Show typing indicator
    typingIndicator.classList.add("visible");
    scrollToBottom();

    // Send to "API"
    const result = await MockDataService.sendMessage(activeSessionId, text);

    // Hide typing
    typingIndicator.classList.remove("visible");

    if (result.success) {
      // Show bot reply
      appendMessage(result.botMessage);
      scrollToBottom();
    }
  }

  // ========== New Chat ==========

  newChatBtn.addEventListener("click", async () => {
    const result = await MockDataService.createNewSession("New Fraud Alert Investigation");
    if (result.success) {
      await loadSessions();
      await openSession(result.session.id);
    }
  });
});
