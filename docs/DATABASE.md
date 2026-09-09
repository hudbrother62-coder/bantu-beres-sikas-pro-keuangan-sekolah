# Database

Migrations live in `supabase/migrations`. Core entities are profiles, schools, members, invitations, classes, students, cash accounts, activities, transactions, bills, payments, allocations, subscriptions, usage metrics and audit logs. Money uses `numeric`, financial records are voided instead of deleted, and workspace access is checked by private security functions.
