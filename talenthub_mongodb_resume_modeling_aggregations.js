// ============================================================================
// TalentHub: MongoDB Document Model, Indexes, CRUD & Aggregation Pipelines
// Run via mongosh: mongosh < mongodb_resumes.js
// ============================================================================

use("talenthub_nosql");
db.resumes.drop();

// 1. CREATE: Insert Candidate Résumés with Flexible/Polymorphic Sections
db.resumes.insertMany([
  {
    candidate_id: 1,
    full_name: "Candidate_001",
    target_role: "Data Scientist",
    hiring_source: "LinkedIn",
    skills: ["Python", "SQL", "Machine Learning", "PyTorch", "Statistics"],
    education: [
      { degree: "M.Sc. Data Science", institution: "IIT Madras", year: 2023 }
    ],
    experience: [
      { company: "FinTech Corp", role: "Data Analyst", years: 2.0, highlights: ["Built churn prediction models"] }
    ],
    certifications: ["AWS Certified Machine Learning"]
  },
  {
    candidate_id: 2,
    full_name: "Candidate_002",
    target_role: "Data Scientist",
    hiring_source: "Referral",
    skills: ["Python", "SQL", "NLP", "TensorFlow", "Docker"],
    education: [
      { degree: "B.Tech Computer Science", institution: "NIT Trichy", year: 2022 }
    ],
    experience: [
      { company: "RetailAI", role: "ML Engineer", years: 2.5 }
    ],
    publications: ["Transformer Optimization at Scale (2023)"] // Flexible schema field
  },
  {
    candidate_id: 3,
    full_name: "Candidate_003",
    target_role: "Backend Software Engineer",
    hiring_source: "LinkedIn",
    skills: ["Java", "Spring Boot", "MySQL", "MongoDB", "Kubernetes"],
    education: [
      { degree: "B.E. Information Technology", institution: "Anna University", year: 2021 }
    ],
    experience: [
      { company: "CloudScale", role: "Software Engineer", years: 3.0 }
    ]
  },
  {
    candidate_id: 4,
    full_name: "Candidate_004",
    target_role: "Backend Software Engineer",
    hiring_source: "Job Portal",
    skills: ["Python", "FastAPI", "PostgreSQL", "Docker", "Redis"],
    education: [
      { degree: "MCA", institution: "VIT", year: 2022 }
    ],
    experience: [
      { company: "PayEase", role: "Backend Developer", years: 2.0 }
    ],
    github_portfolio: "https://github.com/candidate004" // Flexible schema field
  },
  {
    candidate_id: 5,
    full_name: "Candidate_005",
    target_role: "Data Scientist",
    hiring_source: "LinkedIn",
    skills: ["Python", "R", "SQL", "Tableau", "Machine Learning"],
    education: [
      { degree: "M.Sc. Statistics", institution: "ISI Kolkata", year: 2023 }
    ],
    experience: [] // Fresh postgraduate without full-time experience
  }
]);

// 2. INDEXING: Create Text Index on Skills & Compound Index on Role/Source
db.resumes.createIndex({ skills: "text" });
db.resumes.createIndex({ target_role: 1, hiring_source: 1 });

// 3. READ: Full-Text Skill Search
print("\n=== Text Search: Candidates with 'Python' or 'Machine Learning' ===");
printjson(
  db.resumes.find(
    { $text: { $search: "Python \"Machine Learning\"" } },
    { full_name: 1, target_role: 1, skills: 1, score: { $meta: "textScore" }, _id: 0 }
  ).sort({ score: { $meta: "textScore" } }).toArray()
);

// 4. UPDATE: Append a Verified Skill to Candidate 3
db.resumes.updateOne(
  { candidate_id: 3 },
  { $addToSet: { skills: "Kafka" }, $set: { last_verified: new Date() } }
);

// 5. DELETE: Remove Incomplete Test Entry (Demonstrating Delete)
db.resumes.insertOne({ candidate_id: 999, full_name: "Test_User", skills: [] });
db.resumes.deleteOne({ candidate_id: 999 });

// ============================================================================
// AGGREGATION PIPELINE 1: Most Common Skills by Target Role
// ============================================================================
print("\n=== Aggregation 1: Top Skills per Role ===");
printjson(
  db.resumes.aggregate([
    { $unwind: "$skills" },
    {
      $group: {
        _id: { role: "$target_role", skill: "$skills" },
        candidate_count: { $sum: 1 }
      }
    },
    { $sort: { "_id.role": 1, candidate_count: -1 } },
    {
      $group: {
        _id: "$_id.role",
        top_skills: {
          $push: { skill: "$_id.skill", count: "$candidate_count" }
        }
      }
    }
  ]).toArray()
);

// ============================================================================
// AGGREGATION PIPELINE 2: Candidate Pool & Skill Density by Hiring Source
// ============================================================================
print("\n=== Aggregation 2: Candidate Volume & Avg Skill Count by Hiring Source ===");
printjson(
  db.resumes.aggregate([
    {
      $project: {
        hiring_source: 1,
        target_role: 1,
        skill_count: { $size: { $ifNull: ["$skills", []] } }
      }
    },
    {
      $group: {
        _id: "$hiring_source",
        total_resumes: { $sum: 1 },
        avg_skills_per_candidate: { $avg: "$skill_count" },
        roles_targeted: { $addToSet: "$target_role" }
      }
    },
    { $sort: { total_resumes: -1 } }
  ]).toArray()
);