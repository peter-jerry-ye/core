///|
/// Data types for the multi-phase package review workflow.

///|
/// Summary of a single package from Phase 1.
pub struct PackageSummary {
  package_path : String
  files : Array[String]
  summary : String
} derive(Show)

///|
/// A group of related packages from Phase 2.
pub struct PackageGroup {
  name : String
  packages : Array[String]
  rationale : String
} derive(Show)

///|
/// Result of reviewing a package group in Phase 3.
pub struct ReviewResult {
  group_name : String
  packages : Array[String]
  review : String
  success : Bool
  error : String
} derive(Show)
