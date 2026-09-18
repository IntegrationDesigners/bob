# Act of Advocacy options (live form, verified 2026-09-15)

Source: the "1st Act of Advocacy" dropdown of the IBM Champion Program Activity Report
form (https://airtable.com/appuwf3eOGdO6x1oS/pagF5IfVT7m6unCbG/form). 40 entries, one per `- ` line, exactly as
the dropdown renders them; a prefill value or a typed value must match a line
character for character. Order: as scraped. The 2nd/3rd-act dropdowns carry the same
list.

Lookup rule: grep for the mapped entry; read this file in full only when the grep
misses (it is short).

Re-scrape recipe (any browser tool with page JavaScript): open the form, click the
dropdown, read `[...document.querySelectorAll('[role=option]')].map(o => o.innerText.trim())`,
press Escape. An option already selected on the form is hidden from the list and must
be re-inserted. Regenerate this file by script, compare the counts and the checksum
line below before replacing it, and update the date in the title. The 2026-06-29 list
had 4 renamed entries that silently broke prefill until the 2026-09-15 re-scrape.

Checksum of the entry lines (LF-joined; h = (h * 31 + codepoint) mod 2^32): lines 40,
chars 1475, hash 135764526.

- All other videos (e.g. Youtube)
- Analyst Reference
- Attend User Group meeting
- Blog or Article
- Blog on IBM property
- Board Member or UG Leader
- Case Study (Contribute to an IBM Case Study, or Attributed Author, or Quoted)
- Contributing to community.ibm.com (Discussion Threads, Questions)
- Host or Organize IBM-Related Event (multi-customer, non-sales)
- Host or Organize IBM-Related Event (single customer/sales)
- Host Podcast
- Ideas portal
- LInkedIn Post with carousel, video, or 250+ words
- LinkedIn Posts
- LinkedIn reposts
- Mentoring/Coaching
- Newsletter
- Open Source Contributions
- Other Product Team Feedback
- Participate in Sponsor User Program
- Participate in writing an IBM product exam or certification
- Podcast Participant
- Publish or Contribute to a Book or Redbook
- Sales Reference / Participate in Sales Call for IBM Seller (not for your own company sales)
- Social media other (X, Facebook, Insta, TikTok, etc)
- Speak to press on IBMs behalf
- Speaker at IBM Conferences or Events (digital, webinars, regional events)
- Speaker at Non-IBM Conferences or Events (digital, webinars, regional events)
- Survey (from IBM teams)
- Teach courses in IBM Technology
- UG Volunteer
- UG Volunteer - Committee member
- Video with IBM
- Case Study (unattributed business/BP-published case study)
- Complete a Product Review
- Contribute Code, App, or Templates for Community use
- Participate on IBM-Sponsored Advisory Committees/Boards
- Share a Quote (Testimonial) for use by IBM
- Speaker at a User Group or Meetup
- Other
