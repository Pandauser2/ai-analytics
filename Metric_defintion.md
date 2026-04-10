# Metric Definition

## Purpose
This document defines the core fields available for analysis and how to interpret them for business reporting.

## Customer Dataset

| Field | Definition | Notes |
|---|---|---|
| `CustomerID` | Unique identifier per customer. | Primary key at customer level. |
| `Product_Name` | Product the customer signed up for. | Use for product segmentation when available. |
| `Signup_Date` | Date customer signed up. | Acquisition cohort anchor date. |
| `Channel` | Marketing channel that drove signup. | Example: PPC, SEO, Direct, Sales. |
| `First_Activation_Date` | First date customer activated in product. | Engagement milestone. |
| `First_Purchase_Date` | First date customer purchased/subscribed. | Conversion milestone. |
| `Cancel_Date` | Date customer canceled subscription. | May be null or not applicable for non-subscription products. |

## Usage Dataset

| Field | Definition | Notes |
|---|---|---|
| `CustomerID` | Unique identifier per customer. | Join key to customer dataset. |
| `Product_name` | Product used by the customer. | Product context for usage behavior. |
| `Event_Date` | Date of usage action. | Needed for WAU/MAU and retention trends. |
| `Action_type_id` | Action or feature type used in product. | Map IDs to meaningful action labels for reporting. |
| `Usage_count` | Number of times the action occurred for that customer/date. | Aggregation unit for usage intensity. |

## Business and Reporting Guidance
- Clearly state any business assumptions in analysis outputs.
- Audience includes technical and non-technical stakeholders (marketers, PMs).
- Prioritize business insights and decisions over low-level implementation detail.

## Data Availability Note
- If a listed field is missing in the actual loaded table schema, do not infer values.
- Stop and request clarification or the correct source schema before continuing analysis.