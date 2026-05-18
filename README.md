# NOSH7 WhatsApp CRM

An end-to-end **WhatsApp-first Customer Relationship Management system** for NOSH7's subscription cloud kitchen — automates customer lifecycle management from first contact to renewal and reactivation.

## What It Does

Manages every NOSH7 subscriber through their full lifecycle — classifies them daily into buckets automatically, triggers the right WhatsApp message at the right time, and tracks feedback, skips, and payment status in one place.

## Key Features

### Customer Management
- **Customer table** with: plan type (Daily Lite / Weekly Standard / Monthly Premium), payment status, subscription status, dietary preferences (Vegan / Jain / Keto / High-Protein), and delivery zones (A–D)

### Auto-Classification Engine
- **Daily auto-classification** into lifecycle buckets:
  - Lead, New, Active
  - Renewal Due (1 day / 2 days / 3 days)
  - Expired, Dormant
  - Payment Pending, Engaged, At-Risk

### Communication Tracking
- **Message log** — tracks delivered, read, and replied status per message
- **WhatsApp templates table** — HSM (approved) and Conversational templates with approval status
- **Personalized messaging** — templates use customer name and plan details

### Feedback & Retention
- **Feedback table** — ratings, escalation flags, Google review triggers
- **Skip log** — tracks subscription pauses with reason and duration

### Landing & Admin
- **Customer-facing landing page** — 3-step overview, pricing, testimonials, FAQ
- **Admin dashboard** — full CRM management interface

## Tech Stack

- HTML, Vanilla JavaScript
- Supabase (PostgreSQL) — ap-south-1 region
- SQL schema (`schema.sql`)

## Database Tables

| Table | Purpose |
|-------|---------|
| `customers` | Subscriber profiles and status |
| `message_log` | WhatsApp message tracking |
| `feedback` | Ratings and escalations |
| `skip_log` | Subscription pause records |
| `whatsapp_templates` | Message template library |

## Audience

NOSH7 operations team managing subscriber communications and lifecycle; also serves as a reference architecture for WhatsApp-first subscription businesses.