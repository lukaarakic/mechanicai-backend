# 🛠️ MechanicAI — Backend API

### *AI-Driven Vehicle Diagnostics — Rails API*

**MechanicAI** is a Rails 8 API-only backend powering an AI mechanic platform. Users describe their car problems through a conversational interface, and the system uses a progressive diagnostic flow — asking targeted questions before delivering a structured diagnosis powered by GPT-4o.

---

## 🚀 Technical Highlights

- **Progressive AI Diagnostics:** Custom-engineered prompt system using the OpenAI API. The AI asks up to 3 targeted diagnostic questions before delivering a structured diagnosis including causes, severity, DIY feasibility, and estimated repair cost.
- **JWT Authentication:** Devise + devise-jwt for stateless, token-based auth with JTI revocation strategy.
- **Email Confirmation:** Devise confirmable module with support for transactional email providers.
- **RESTful API Design:** Versioned API (`/api/v1/`) with namespaced controllers and nested resources.
- **UUID Primary Keys:** All tables use UUIDs for security and scalability.
- **Multi-model Relationships:** Users → Cars → Chats → Messages with proper foreign key constraints and dependent destroy callbacks.

---

## 🛠️ Tech Stack

![Rails](https://img.shields.io/badge/Rails-8.1-CC0000?style=for-the-badge&logo=rubyonrails&logoColor=white)
![Ruby](https://img.shields.io/badge/Ruby-3.4-CC342D?style=for-the-badge&logo=ruby&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)
![OpenAI](https://img.shields.io/badge/OpenAI-GPT--4o-412991?style=for-the-badge&logo=openai&logoColor=white)
![JWT](https://img.shields.io/badge/JWT-Auth-000000?style=for-the-badge&logo=jsonwebtokens&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)

---

## 📐 Data Model

```
User
 ├── has_many :cars
 └── has_many :chats
      Car
       └── has_many :chats
            Chat
             ├── belongs_to :user
             ├── belongs_to :car
             └── has_many :messages
                  Message
                   └── belongs_to :chat
```

---

## 🔌 API Endpoints

### Auth
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/register` | Register a new user |
| POST | `/api/v1/login` | Login, returns JWT in `Authorization` header |
| DELETE | `/api/v1/logout` | Logout, revokes JWT |

### Cars
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/cars` | List all cars for current user |
| POST | `/api/v1/cars` | Create a car |
| GET | `/api/v1/cars/:id` | Get a car |
| PATCH | `/api/v1/cars/:id` | Update a car |
| DELETE | `/api/v1/cars/:id` | Delete a car |

### Chats
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/chats` | List all chats |
| POST | `/api/v1/chats` | Create a chat for a car |
| GET | `/api/v1/chats/:id` | Get chat with messages |
| DELETE | `/api/v1/chats/:id` | Delete a chat |

### Messages
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/chats/:chat_id/messages` | Send a message, triggers AI response |

---

## 🤖 AI Diagnostic Flow

The AI follows a structured 4-step flow:

1. **Message 1** — User describes the problem. AI asks one targeted diagnostic question.
2. **Message 2** — AI asks a second follow-up question.
3. **Message 3** — AI asks one final question.
4. **Message 4+** — AI delivers a full structured diagnosis:

---

## 📦 Local Setup

### Prerequisites
- Ruby 3.4+
- Docker (for PostgreSQL)
- OpenAI API key

### 1. Clone the repo
```bash
git clone https://github.com/lukaarakic/mechanicai-backend.git
cd mechanicai-backend
```

### 2. Install dependencies
```bash
bundle install
```

### 3. Start PostgreSQL via Docker
```bash
docker run --name mechanicai-db \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_USER=postgres \
  -p 5432:5432 \
  -d postgres:16
```

### 4. Configure credentials
```bash
rails credentials:edit
```

Add:
```yaml
openai_api_key: your_openai_key_here
jwt_secret_key: your_secret_here
```

### 5. Configure database
Update `config/database.yml` with your local PostgreSQL credentials.

### 6. Run migrations
```bash
rails db:create db:migrate
```

### 7. Start the server
```bash
rails s
```

API available at `http://localhost:3000`

---

## 🔐 Authentication

All protected endpoints require a JWT token in the `Authorization` header:

```
Authorization: Bearer your_jwt_token_here
```

The token is returned in the response headers after a successful login.
