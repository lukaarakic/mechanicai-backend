# 🛠️ MechanicAI — Backend API

### *AI-Driven Vehicle Diagnostics — Rails 8 API*

**MechanicAI** is a professional-grade Rails 8 API powering an intelligent conversational vehicle diagnostic platform. By combining **GPT-5** with a targeted diagnostic state machine and a subscription-based model, it provides users with high-accuracy vehicle troubleshooting, severity assessments, and repair cost estimations.

---

## 🚀 Technical Highlights

* **Advanced Authentication (Rodauth):** Uses Rodauth for secure, low-overhead JWT authentication. JWT generation and account management are handled internally for maximum security.
* **Progressive AI Diagnostic Flow:** A "3-question then diagnose" logic ensures context-aware AI responses. The system gathers specifics before delivering a technical breakdown.
* **Rich Markdown Responses:** The AI generates structured reports including technical causes, severity levels, and cost estimates, pre-formatted for frontend rendering.
* **Monetization Ready:** Built-in subscription management logic (`subscribe`, `cancel`, `status`) to gate premium AI features and diagnostic reports.
* **UUID Architecture:** Native PostgreSQL UUIDs across all tables to prevent ID enumeration and improve database scalability.
* **Health Monitoring:** Includes Rails 8 `/up` health check for zero-downtime deployment monitoring.

---

## 🛠️ Tech Stack

![Rails](https://img.shields.io/badge/Rails-8.1-CC0000?style=for-the-badge&logo=rubyonrails&logoColor=white)
![Ruby](https://img.shields.io/badge/Ruby-3.4-CC342D?style=for-the-badge&logo=ruby&logoColor=white)
![Rodauth](https://img.shields.io/badge/Rodauth-Auth-7b0607?style=for-the-badge&logo=ruby&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-316192?style=for-the-badge&logo=postgresql&logoColor=white)
![OpenAI](https://img.shields.io/badge/OpenAI-GPT--5-412991?style=for-the-badge&logo=openai&logoColor=white)

---

## 🔌 API Endpoints

### 🔑 Authentication & Profile
| Method | Endpoint | Description |
|:-------|:---------|:------------|
| POST | `/api/v1/login` | Login & receive JWT (Rodauth) |
| GET | `/api/v1/current-user` | Get current authenticated user details |
| PATCH | `/api/v1/onboard` | Complete initial user setup |
| PATCH | `/api/v1/update-user` | Update profile information |

### 🚗 Garage (Cars)
| Method | Endpoint | Description |
|:-------|:---------|:------------|
| GET | `/api/v1/cars` | List all cars for current user |
| POST | `/api/v1/cars` | Add a new car to the garage |
| GET | `/api/v1/cars/:id` | Get specific car details |
| PATCH | `/api/v1/cars/:id` | Update car info (Year/Make/Model) |
| DELETE | `/api/v1/cars/:id` | Remove car from garage |

### 💬 Diagnostics (Chats & Messages)
| Method | Endpoint | Description |
|:-------|:---------|:------------|
| GET | `/api/v1/chats` | List user's diagnostic history |
| POST | `/api/v1/chats` | Start a new AI diagnostic session |
| GET | `/api/v1/chats/:id` | Get full chat history + AI diagnosis |
| POST | `/api/v1/chats/:id/messages` | Send user reply; triggers next AI response |

### 💳 Payments & Subscription
| Method | Endpoint | Description |
|:-------|:---------|:------------|
| GET | `/api/v1/accounts/:id/payment/subscription` | Check current subscription status |
| POST | `/api/v1/accounts/:id/payment/subscribe` | Initialize a new subscription |
| POST | `/api/v1/accounts/:id/payment/cancel` | Cancel an active subscription |

---

## 📐 Response Example
`GET /api/v1/chats/:id`

```json
{
  "chat": {
    "id": "026063ef-830a-4a0e-8bb9-6966dd24c88f",
    "account_id": "a02eb00e-e1b6-4490-a380-d09d5ad4b567",
    "car_id": "26847986-b1ab-4847-8e7a-24557784f563",
    "category": "TRANSMISSION",
    "title": "The clutch is slipping or shaking.",
    "created_at": "2026-04-01T14:29:22.949Z"
  },
  "messages": [
    {
      "role": "user",
      "content": "My car shakes when I start in 1st gear..."
    },
    {
      "role": "assistant",
      "content": "Does it happen more on hills or flat ground?"
    },
    {
      "role": "assistant",
      "content": "## Most Likely Causes\n- Worn Clutch... \n## Severity\n- Medium..."
    }
  ]
}
```

---

## 📦 Development Setup

### 1. Prerequisites
Ensure you have the following installed:
- **Ruby 3.4.0+**
- **Bundler** (`gem install bundler`)
- **Docker Desktop** (for PostgreSQL)
- **OpenAI API Key**

### 2. Clone & Install Dependencies
```bash
git clone https://github.com/lukaarakic/mechanicai-backend.git
cd mechanicai-backend
bundle install
```
### 3. Database Setup (Docker)
Run the PostgreSQL container. If you already have a container named `mechanicai-db`, remove it first with `docker rm -f mechanicai-db`.

```bash
docker run --name mechanicai-db \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_USER=postgres \
  -p 5432:5432 \
  -d postgres:16
```

### 4. Configuration & Secrets
Rails 8 uses encrypted credentials. To edit them, you must specify an editor (like VS Code or Nano):

Bash
# For VS Code:
```js
# For VS Code:
EDITOR="code --wait" rails credentials:edit

# For Nano (Terminal):
EDITOR="nano" rails credentials:edit
```

### 5. Initialize Database
```
rails db:create
rails db:migrate
```
### 6. Launch the API
```
rails s
```

The API will be live at http://localhost:3000. You can verify it's running by visiting http://localhost:3000/up in your browser.
