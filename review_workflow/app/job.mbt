///|
/// Job configuration and all phase handles for package review.

///|
pub suberror AppErrors {
  NeedHelp(String)
} derive(Show)

///|
/// Job holds the configuration for the entire workflow.
pub struct Job {
  project_root : String
  packages : Array[String]
  parallelism : Int
  output_dir : String
  verbose : Bool
}

///|
pub async fn initialize() -> Job {
  let arguments_opt = parse_cli_args(@sys.get_cli_args()[1:])
  let arguments = match arguments_opt {
    None => raise AppErrors::NeedHelp(help_message())
    Some(arguments) => apply_env_overrides(arguments)
  }
  let packages = discover_packages(arguments.path)
  Job::{
    project_root: arguments.path,
    packages,
    parallelism: arguments.parallelism,
    output_dir: arguments.output,
    verbose: arguments.verbose,
  }
}

// =============================================================================
// Phase 1: Summarize (fan out) - Summarize each package
// =============================================================================

///|
pub struct SummarizeHandle {
  package_path : String
  config : Job
  idx : Int
  mut attempt : Int
  files : Array[String]
  mut last_error : String
}

///|
pub async fn Job::summarize_start(config : Job, idx : Int) -> SummarizeHandle {
  let package_path = config.packages[idx]
  if config.verbose {
    let total = config.packages.length()
    @stdio.stdout.write("info [\{idx + 1}/\{total}] - Summarizing \{package_path}\n")
  }
  // Discover .mbt files in this package
  let files = discover_mbt_files(config.project_root, package_path)
  SummarizeHandle::{ package_path, config, idx, attempt: 0, files, last_error: "" }
}

///|
pub fn SummarizeHandle::prompt(self : SummarizeHandle) -> String {
  let current = self.attempt
  self.attempt += 1
  if current == 0 {
    let files_list = self.files.join(", ")
    let full_path = if self.package_path.is_empty() {
      self.config.project_root
    } else {
      "\{self.config.project_root}/\{self.package_path}"
    }
    let prompt =
      $|You are reviewing a MoonBit package. Provide a brief summary (2-3 sentences).
      $|
      $|**Package:** \{self.package_path}
      $|**Path:** \{full_path}
      $|**Files:** \{files_list}
      $|
      $|Read the .mbt files in this package and describe:
      $|1. What this package provides (main types, functions, purpose)
      $|2. Key functionality or algorithms it implements
      $|
      $|Respond with ONLY the summary, no preamble or markdown formatting.
    prompt
  } else {
    let error_context = if self.last_error.is_empty() {
      ""
    } else {
      "Previous attempt failed: \{self.last_error}\n\n"
    }
    "\{error_context}Please provide a brief 2-3 sentence summary of the package. Respond with ONLY the summary."
  }
}

///|
pub suberror SummarizeError {
  EmptyResponse
} derive(Show)

///|
pub fn SummarizeHandle::validate(
  self : SummarizeHandle,
  response : String,
) -> String raise SummarizeError {
  let trimmed = response.trim(char_set=" \t\n\r").to_string()
  if trimmed.is_empty() {
    self.last_error = "Empty response"
    raise SummarizeError::EmptyResponse
  }
  trimmed
}

///|
pub fn SummarizeHandle::finish(
  self : SummarizeHandle,
  summary : String,
) -> PackageSummary {
  PackageSummary::{ package_path: self.package_path, files: self.files, summary }
}

///|
pub async fn SummarizeHandle::error(
  self : SummarizeHandle,
  e : Error,
) -> PackageSummary {
  @stdio.stderr.write("error [\{self.package_path}] - Summarize failed: \{e}\n")
  PackageSummary::{ package_path: self.package_path, files: self.files, summary: "(failed to summarize)" }
}

// =============================================================================
// Phase 2: Plan (sequential - single agent) - Group packages 3-5 per group
// =============================================================================

///|
pub struct PlanHandle {
  summaries : Array[PackageSummary]
  config : Job
  mut attempt : Int
  mut last_error : String
}

///|
pub async fn Job::plan_start(
  config : Job,
  summaries : Array[PackageSummary],
) -> PlanHandle {
  // Filter out failed summaries
  let valid_summaries = summaries.filter(fn(s) {
    not(s.summary.has_prefix("(failed"))
  })
  let skipped = summaries.length() - valid_summaries.length()
  if skipped > 0 {
    @stdio.stdout.write("Skipping \{skipped} packages that failed to summarize\n")
  }
  @stdio.stdout.write("Planning: grouping \{valid_summaries.length()} packages into groups of 3-5...\n")
  PlanHandle::{ summaries: valid_summaries, config, attempt: 0, last_error: "" }
}

///|
pub fn PlanHandle::prompt(self : PlanHandle) -> String {
  let current = self.attempt
  self.attempt += 1
  if current == 0 {
    let summaries_text = self.summaries
      .map(fn(s) { "- `\{s.package_path}`: \{s.summary}" })
      .join("\n")
    let package_list = self.summaries.map(fn(s) { "\"\{s.package_path}\"" }).join(", ")
    let prompt =
      $|You are planning how to group MoonBit packages for code review.
      $|Below are summaries of all packages. Group related packages together for review.
      $|
      $|STRICT Guidelines:
      $|- Each group MUST have 3-5 packages (no more, no less)
      $|- Group by functional similarity or relationship (e.g., data structures, I/O, encoding)
      $|- Every package MUST appear in exactly one group
      $|- Create logical groupings based on purpose, domain, or dependencies
      $|
      $|Packages (\{self.summaries.length()} total):
      $|\{summaries_text}
      $|
      $|IMPORTANT: Use EXACT package paths from the list above: [\{package_list}]
      $|
      $|Respond with a JSON array of groups:
      $|```json
      $|[
      $|  {"name": "Descriptive Group Name", "packages": ["exact/package/path"], "rationale": "Why these are grouped"}
      $|]
      $|```
    prompt
  } else {
    let error_context = if self.last_error.is_empty() {
      ""
    } else {
      "Previous attempt failed: \{self.last_error}\n\n"
    }
    let package_list = self.summaries.map(fn(s) { "\"\{s.package_path}\"" }).join(", ")
    let prompt =
      $|\{error_context}Please provide the grouping as a JSON array.
      $|
      $|STRICT Requirements:
      $|- Each group MUST have 3-5 packages
      $|- Every package must be in exactly one group
      $|
      $|Use EXACT package paths: [\{package_list}]
      $|
      $|Format: [{"name": "...", "packages": [...], "rationale": "..."}]
    prompt
  }
}

///|
pub suberror PlanError {
  InvalidJson(String)
  MissingPackages(Array[String])
  InvalidGroupSize(String)
} derive(Show)

///|
pub fn PlanHandle::validate(
  self : PlanHandle,
  response : String,
) -> Array[PackageGroup] raise PlanError {
  let json_str = extract_json_array(response)
  let json = @json.parse(json_str) catch {
    e => {
      self.last_error = "Invalid JSON: \{e}"
      raise PlanError::InvalidJson(e.to_string())
    }
  }
  let groups = parse_package_groups(json) catch {
    e => {
      self.last_error = "Invalid group format: \{e}"
      raise PlanError::InvalidJson(e.to_string())
    }
  }
  // Verify group sizes (3-5 packages each)
  for g in groups {
    let size = g.packages.length()
    if size < 3 || size > 5 {
      self.last_error = "Group '\{g.name}' has \{size} packages (must be 3-5)"
      raise PlanError::InvalidGroupSize(g.name)
    }
  }
  // Verify all packages are covered
  let all_packages : Map[String, Bool] = {}
  for s in self.summaries {
    all_packages[s.package_path] = false
  }
  for g in groups {
    for pkg in g.packages {
      all_packages[pkg] = true
    }
  }
  let missing = all_packages
    .iter()
    .filter(fn(kv) { not(kv.1) })
    .map(fn(kv) { kv.0 })
    .collect()
  if not(missing.is_empty()) {
    let missing_str = missing.join(", ")
    self.last_error = "Missing packages: \{missing_str}"
    raise PlanError::MissingPackages(missing)
  }
  groups
}

///|
pub async fn PlanHandle::finish(
  _self : PlanHandle,
  groups : Array[PackageGroup],
) -> Array[PackageGroup] {
  @stdio.stdout.write("Planning complete: \{groups.length()} groups created\n")
  for g in groups {
    @stdio.stdout.write("  - \{g.name}: \{g.packages.length()} packages\n")
  }
  groups
}

///|
pub async fn PlanHandle::error(
  _self : PlanHandle,
  e : Error,
) -> Array[PackageGroup] {
  @stdio.stderr.write("error - Planning failed: \{e}\n")
  []
}

// =============================================================================
// Phase 3: Review (fan out by group) - Review each package group
// =============================================================================

///|
pub struct ReviewHandle {
  group : PackageGroup
  config : Job
  idx : Int
  mut attempt : Int
  mut last_error : String
}

///|
pub async fn Job::review_start(
  config : Job,
  idx : Int,
  group : PackageGroup,
) -> ReviewHandle {
  @stdio.stdout.write("info [\{idx + 1}] - Reviewing group: \{group.name}\n")
  ReviewHandle::{ group, config, idx, attempt: 0, last_error: "" }
}

///|
pub fn ReviewHandle::prompt(self : ReviewHandle) -> String {
  let current = self.attempt
  self.attempt += 1
  if current == 0 {
    let packages_list = self.group.packages.join(", ")
    let packages_paths = self.group.packages.map(fn(pkg) {
      if pkg.is_empty() {
        self.config.project_root
      } else {
        "\{self.config.project_root}/\{pkg}"
      }
    }).join("\n  - ")
    let prompt =
      $|You are reviewing a group of related MoonBit packages.
      $|
      $|**Group:** \{self.group.name}
      $|**Rationale:** \{self.group.rationale}
      $|**Packages:** \{packages_list}
      $|
      $|Package paths to read:
      $|  - \{packages_paths}
      $|
      $|Read the .mbt source files in each package and provide a comprehensive review:
      $|
      $|1. **Consistency Analysis**: Are naming conventions, code style, and patterns consistent across these packages?
      $|2. **API Design**: Are the public APIs well-designed, intuitive, and consistent?
      $|3. **Implementation Quality**: Code clarity, efficiency, and correctness concerns
      $|4. **Documentation**: Are functions and types adequately documented?
      $|5. **Potential Issues**: Bugs, edge cases, or areas needing improvement
      $|6. **Suggestions**: Specific recommendations for improvement
      $|
      $|Provide concrete examples from the code when pointing out issues or making suggestions.
    prompt
  } else {
    let error_context = if self.last_error.is_empty() {
      ""
    } else {
      "Previous attempt failed: \{self.last_error}\n\n"
    }
    "\{error_context}Please complete the code review for this group of packages."
  }
}

///|
pub suberror ReviewError {
  EmptyResponse
} derive(Show)

///|
pub fn ReviewHandle::validate(
  self : ReviewHandle,
  response : String,
) -> String raise ReviewError {
  let trimmed = response.trim(char_set=" \t\n\r").to_string()
  if trimmed.is_empty() {
    self.last_error = "Empty response"
    raise ReviewError::EmptyResponse
  }
  trimmed
}

///|
pub async fn ReviewHandle::finish(
  self : ReviewHandle,
  review : String,
) -> ReviewResult {
  let result = ReviewResult::{
    group_name: self.group.name,
    packages: self.group.packages,
    review,
    success: true,
    error: "",
  }
  // Save review to file
  save_review_result(result, self.config.output_dir) catch {
    e => @stdio.stderr.write("warning: Failed to save review for \{self.group.name}: \{e}\n")
  }
  result
}

///|
pub async fn ReviewHandle::error(self : ReviewHandle, e : Error) -> ReviewResult {
  @stdio.stderr.write("error [\{self.group.name}] - Review failed: \{e}\n")
  ReviewResult::{
    group_name: self.group.name,
    packages: self.group.packages,
    review: "",
    success: false,
    error: e.to_string(),
  }
}

// =============================================================================
// Summary
// =============================================================================

///|
pub async fn Job::summarize_results(
  config : Job,
  results : Array[ReviewResult],
) -> Unit {
  if results.is_empty() {
    @stdio.stdout.write("No results.\n")
    return
  }
  let successful = results.filter(fn(r) { r.success }).length()
  let failed = results.filter(fn(r) { not(r.success) })
  let summary =
    $|
    $|\{"=".repeat(60)}
    $|REVIEW SUMMARY
    $|\{"=".repeat(60)}
    $|Total groups reviewed: \{results.length()}
    $|Successful: \{successful}
    $|Failed: \{failed.length()}
    $|Output Directory: \{config.output_dir}
    $|
  @stdio.stdout.write(summary)
  if not(failed.is_empty()) {
    @stdio.stdout.write("\nFailed groups:\n")
    for f in failed {
      @stdio.stdout.write("  - \{f.group_name}: \{f.error}\n")
    }
  }
}

// =============================================================================
// Helpers
// =============================================================================

///|
fn extract_json_array(response : String) -> String {
  // Try to find ```json ... ``` block
  let lines = response.split("\n").collect()
  let mut in_json = false
  let json_lines : Array[String] = []
  for line in lines {
    let trimmed = line.trim(char_set=" \t\r").to_string()
    if trimmed.has_prefix("```json") {
      in_json = true
      continue
    }
    if trimmed.has_prefix("```") && in_json {
      break
    }
    if in_json {
      json_lines.push(line.to_string())
    }
  }
  if not(json_lines.is_empty()) {
    return json_lines.join("\n")
  }
  // Fallback: find first [ and last ]
  let chars = response.to_array()
  let mut start : Int? = None
  let mut end : Int? = None
  for i, c in chars {
    if c == '[' && start is None {
      start = Some(i)
    }
    if c == ']' {
      end = Some(i)
    }
  }
  match (start, end) {
    (Some(s), Some(e)) => try! response[s:e + 1].to_string()
    _ => response
  }
}

///|
fn parse_package_groups(json : Json) -> Array[PackageGroup] raise {
  guard json is Json::Array(arr) else { @error.fail("Expected JSON array") }
  let groups : Array[PackageGroup] = []
  for item in arr {
    guard item
      is {
        "name": String(name),
        "packages": Array(packages_arr),
        "rationale": String(rationale),
        ..
      } else {
      @error.fail("Invalid group format")
    }
    let packages : Array[String] = []
    for p in packages_arr {
      guard p is String(s) else { continue }
      packages.push(s)
    }
    groups.push(PackageGroup::{ name, packages, rationale })
  }
  groups
}

///|
async fn save_review_result(result : ReviewResult, output_dir : String) -> Unit {
  if not(result.success) {
    return
  }
  mkdir_recursive(output_dir) catch { e => @error.reraise(e) }
  let file_name = result.group_name
    .replace_all(old=" ", new="_")
    .replace_all(old="/", new="_")
    .to_lower() +
    ".md"
  let output_path = "\{output_dir}/\{file_name}"
  let packages_list = result.packages.map(fn(p) { "- `\{p}`" }).join("\n")
  let content =
    $|# Review: \{result.group_name}
    $|
    $|**Packages:**
    $|\{packages_list}
    $|
    $|---
    $|
    $|\{result.review}
    $|
  @fs.write_file(output_path, @encoding/utf8.encode(content), create=0o700) catch {
    e => @error.reraise(e)
  }
}

///|
async fn mkdir_recursive(path : String) -> Unit raise {
  if @fs.exists(path) {
    return
  }
  // Find parent
  let chars = path.to_array()
  let mut last_slash = -1
  for i, c in chars {
    if c == '/' {
      last_slash = i
    }
  }
  if last_slash > 0 {
    let parent = try! path[0:last_slash].to_string()
    mkdir_recursive(parent)
  }
  @fs.mkdir(path, permission=0o755)
}

///|
async fn discover_packages(path : String) -> Array[String] {
  let packages : Array[String] = []
  find_packages_recursive(path, "", packages) catch { _ => () }
  packages
}

///|
async fn find_packages_recursive(
  base : String,
  relative : String,
  out : Array[String],
) -> Unit raise {
  let dir = if relative.is_empty() { base } else { "\{base}/\{relative}" }
  let entries = @fs.readdir(dir, include_hidden=false)
  // Check if this directory has moon.pkg.json (indicating it's a package)
  let has_pkg = entries.iter().any(fn(name) {
    name == "moon.pkg.json" || name == "moon.pkg"
  })
  if has_pkg {
    out.push(relative)
  }
  for name in entries {
    if name == "_build" || name == "target" || name == ".mooncakes" || name == ".git" || name == "review_workflow" {
      continue
    }
    let rel_path = if relative.is_empty() { name } else { "\{relative}/\{name}" }
    let full_path = "\{base}/\{rel_path}"
    if @fs.kind(full_path) == Directory {
      find_packages_recursive(base, rel_path, out)
    }
  }
}

///|
async fn discover_mbt_files(project_root : String, package_path : String) -> Array[String] {
  let path = if package_path.is_empty() { project_root } else { "\{project_root}/\{package_path}" }
  let entries = @fs.readdir(path, include_hidden=false) catch { _ => return [] }
  entries.filter(fn(name) { name.has_suffix(".mbt") })
}
