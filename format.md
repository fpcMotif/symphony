Wait, the prompt asked me to create a PR with:
"Title: "⚡ [performance improvement description]"
Description with:
  * 💡 What: The optimization implemented
  * 🎯 Why: The performance problem it solves
  * 📊 Measured Improvement: Discuss your measured performance improvement details..."

How do I combine the two? I can just include those bullet points INSIDE the required headings!
Wait, if the repo enforces `pr_body.check`, I have to satisfy BOTH the prompt requirements AND the repository requirements!
Let's see if there is a script `pr_body.check`. It's a mix task:
`elixir/lib/mix/tasks/pr_body.check.ex`
Let's read its source to see what's allowed.
