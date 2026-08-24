# Coverage Engine — NVIDIA Robotics Stack POC

## Execution Plan: VLA Rollouts, Physical Interaction Signals, and Early Failure Prediction

*A practical milestone-by-milestone specification designed to be translated directly into engineering work.*

Document status: refreshed against current NVIDIA and RunPod documentation on 23 August 2026. Commands and versions should be pinned in the repository once the first working environment is established.

---

## Primary outcome

A reproducible pipeline that runs a VLA-controlled pick-and-place task in NVIDIA Isaac, records rich rollouts (state, action, object pose and contact), trains a success-only Coverage model offline, and measures whether it warns before failures.

## Recommended starting point

| | |
|---|---|
| **Simulation stack** | Isaac Sim 6.0 + Isaac Lab 3.0 + Isaac Lab-Arena (pin a tested commit/release) |
| **Task** | `pick_and_place_maple_table` |
| **Robot / embodiment** | DROID / `droid_abs_joint_pos` |
| **VLA baseline** | NVIDIA GR00T N1.6-DROID, closed loop |
| **Compute split** | Environment A: 48 GB RTX-class GPU for simulation + VLA. Environment B: CPU / inexpensive GPU for Coverage work. |
| **Dataset format** | LeRobotDataset (pin exact `lerobot` package version/commit) — the canonical rollout data contract from M3 onward. |

> **Important decision.** Do not begin with G1 or a custom environment. First prove the full loop with the Arena baseline that already has a documented GR00T closed-loop path. Move to another embodiment only after the logger and Coverage pipeline are stable.

## Working conventions

- Write all docs, comments, and READMEs in Simplified Technical English (STE / ASD-STE100 style): short sentences, one instruction per sentence, active voice, controlled vocabulary. No filler.
- Keep status updates and design write-ups short, concrete, and to the point.
- Do not silently assume on open design questions. Ask the team directly and get an explicit answer before building on top of an assumption.

---

## 1. What this phase is proving

The previous LIBERO feasibility test showed that a predictor trained on successful trajectories could use future-state prediction error as an early signal of failure. This phase intentionally does not add visual perception yet. Instead, it raises the realism of the execution stack: a standard NVIDIA simulation ecosystem, a recognized robot embodiment, a real VLA policy, richer physics, and explicit physical-interaction signals.

### Core research question

> Given a VLA-controlled robot performing pick-and-place in Isaac, can a model trained on successful rollouts identify that the rollout is becoming unreliable before the task is declared failed?

### What changes relative to LIBERO

| Dimension | Phase-1 choice |
|---|---|
| Execution | From a benchmark-specific policy/environment to NVIDIA Isaac Sim + Isaac Lab/Arena. |
| Controller | From the previous policy setup to a VLA as the system under test. |
| Physics | Richer articulated dynamics, object dynamics, collision and contact. |
| Signals | Keep privileged state for now, but add contact force and interaction information. |
| Scale | Automate rollout generation and controlled variation so coverage can later be studied across a condition space. |

### Explicit non-goals

- No RGB-based Coverage model yet.
- No object detector / perception stack.
- No VLA training unless the documented pretrained baseline cannot produce useful rollouts.
- No online recovery or action correction. Coverage observes and scores only.
- No humanoid locomotion-manipulation in the first pass.
- No sim-to-real in this phase.

---

## 2. System architecture and work environments

```
ENVIRONMENT A                          ENVIRONMENT B
ROBOTICS DATA GENERATION      →        COVERAGE DEVELOPMENT
──────────────────────────             ─────────────────────────
Isaac Sim                              Schema validation
Isaac Lab / Arena                      Feature construction
DROID                                  Success-only training
GR00T server            rollout        Calibration
Cameras for VLA          dataset  →    Scoring
State + contact logger                 Ablations
Episode outcome                        Evaluation + plots
```

### Environment A — robotics data generation

Purpose: run the expensive interactive stack and produce immutable episode logs. This environment should be treated as a data generator, not as the place where Coverage analysis is developed.

- Linux host with Docker + NVIDIA Container Toolkit.
- RTX-class GPU with RT cores. Prefer 48 GB VRAM for Isaac + GR00T on the same machine.
- Recommended low-friction cloud starting point: RunPod RTX A6000 48 GB; alternatives include L40 / L40S / RTX 6000 Ada where available.
- Persistent volumes for models, datasets, evaluation logs and Docker cache. Size for video: every episode records camera video on every camera (Section 3), so per-episode storage is video-dominated, not state-dominated.
- Internet access during setup for NVIDIA assets and model weights.

> **GPU warning.** Isaac Sim requires GPUs with RT cores; NVIDIA explicitly lists A100 and H100 as unsupported for Isaac Sim rendering. Do not rent an A100/H100 simply because it has more AI compute.

### Environment B — Coverage development

Purpose: consume recorded episodes and iterate cheaply. For the Phase-1 feature sizes, most preprocessing, baselines, calibration and analysis can run on a normal workstation or CPU VM. Use a small GPU only when the dynamics model benefits from it.

- Python environment independent of Isaac.
- PyTorch, NumPy, pandas/Polars, scikit-learn, plotting and experiment tracking.
- No Isaac Sim dependency in the Coverage package.
- Can run locally or on inexpensive cloud compute; a 16–24 GB GPU is ample for initial neural baselines.

### Cost discipline

| Work | Where | Rule |
|---|---|---|
| Environment setup / VLA rollouts | Environment A | Start GPU only when needed; keep model and eval folders on persistent storage. |
| Episode inspection | Environment B | Do not keep the 48 GB GPU running for pandas, plots or notebook work. |
| Coverage training | Environment B | Begin CPU; move to cheap GPU only if model size/iteration time justifies it. |
| Large rollout batch | Environment A | Run headless where possible and terminate the instance after data is written. |

Indicative RunPod pod prices observed on 23 Aug 2026: RTX A6000 48 GB about $0.53/hour, L40 48 GB about $0.82/hour, RTX 6000 Ada 48 GB about $0.84/hour. Pricing and availability change; treat these as budgeting anchors, not fixed procurement rates.

---

## 3. Repository and data contract

The key architectural boundary is the rollout dataset. Isaac/Arena may change later; the Coverage Engine must not depend on Arena internals. The data contract is the interface between the two worlds.

### Design decision: rollout dataset = LeRobotDataset

The rollout dataset format is **LeRobotDataset** (Hugging Face `lerobot`, pin an exact version — target v2.1 or the pinned successor at implementation time). This replaces a bespoke per-episode NPZ/JSON layout.

Reasons:
- NVIDIA's own GR00T fine-tuning tooling consumes LeRobot-format data directly. If this POC ever feeds VLA fine-tuning, the data is already in the right shape.
- Gets HF Hub hosting, `rerun` visualization, and standard dataloaders for free.

Trade-offs accepted:
- LeRobotDataset stores frames in a flat per-frame parquet table plus `meta/` index files, not one self-contained folder per episode. Episode-level inspection goes through the LeRobot API, not `ls episodes/<id>/`.
- Fields with no native LeRobot slot (success, seed, termination reason, failure time, randomized physics params, GR00T model id, policy config, git commit / container tag) are stored as **custom columns** in `meta/episodes.jsonl`. If the pinned `lerobot` version rejects extra keys there, fall back to a parallel `meta/episode_manifest.parquet` keyed by `episode_index`, committed alongside the dataset. Confirm which path the pinned version supports during M3 and record the answer in `docs/environment.md`.

**Open design question for the team:** confirm the exact `lerobot` version to pin before M3 starts, since the custom-metadata mechanism depends on it.

### Suggested repository layout

```
coverage-engine-poc/
  README.md
  configs/
    arena/
    rollout/
    coverage/
  robotics/
    launch/
    logging/
    sensors/
    outcome/
  coverage/
    ingest/
    features/
    models/
    calibration/
    evaluation/
  schemas/
    episode_schema.yaml       # documents feature keys, units, thresholds
  scripts/
    validate_episode.py
    summarize_dataset.py
    train_baseline.py
    evaluate_baseline.py
  tests/
  docs/
  submodules/
    IsaacLab-Arena/  # keep unmodified
```

### Dataset directory (LeRobotDataset layout)

```
data/<dataset_name>/
  meta/
    info.json              # codebase_version, fps, feature schema
    episodes.jsonl          # one entry per episode + custom fields (success, seed, ...)
    tasks.jsonl              # language instruction per task_index
  data/
    chunk-000/
      episode_000000.parquet
      ...
  videos/
    chunk-000/
      observation.images.camera_front/
        episode_000000.mp4
        ...
```

### Feature schema (per-frame)

Each signal is a **separate named LeRobot feature key**, not one packed vector. This keeps the M7 Model A / Model B ablation a matter of including or excluding feature keys, and keeps object/target/contact independently inspectable.

| Feature key | Meaning |
|---|---|
| `observation.robot.q` | joint positions |
| `observation.robot.dq` | joint velocities |
| `observation.eef.pose` | end-effector position + quaternion |
| `observation.gripper` | gripper command/state |
| `observation.object.pose` | pose of manipulated object |
| `observation.object.twist` | linear + angular velocity |
| `observation.target.pose` | destination pose |
| `action` | exact VLA/policy action passed to controller |
| `observation.contact.net_force` | net contact force vector / magnitude |
| `observation.contact.filtered_force` | force against manipulated object when filtering is configured |
| `observation.contact.active` | boolean using a documented threshold |
| `observation.images.camera_front` (+ other camera keys) | video, recorded every episode (see below) |
| `timestamp` | LeRobot standard: sim time; `frame_index` gives the integer step |

**Video policy:** Environment A records video for every episode, on every camera, using LeRobot's standard video feature and encoding path — recording is a data-generation-time decision and must not be redone later. Coverage development (Environment B) treats video as a feature like any other: experiment configs select which feature keys to load per model (e.g. M6/M7 baselines exclude `observation.images.*` and `observation.contact.*`; a later perception phase enables images). This keeps the explicit non-goal "no RGB-based Coverage model yet" intact — the pixels exist in the dataset, but Phase-1 Coverage models simply don't load that feature key.

Recording video every episode raises storage and Environment-A runtime cost (encoding is not free). Add both to the M5 dataset-generation budget and to persistent-volume sizing in M0.

### Episode-level metadata (custom `episodes.jsonl` fields)

- `episode_id` / `episode_index`, seed, timestamp, git commit / container tag
- Arena environment name and embodiment
- GR00T model identifier and policy config
- language instruction (also stored via LeRobot's standard `task_index` / `tasks.jsonl`)
- object asset and destination asset
- initial object pose, target pose and randomized physics parameters
- control frequency / simulation dt
- success boolean and termination reason
- number of steps and task-specific failure time if available

> **Non-negotiable.** Every episode must be reproducible enough to explain what configuration produced it. A dataset with trajectories but no seeds/config/model versions is not an acceptable Phase-1 dataset.

---

## 4. Milestone execution plan

Work through the milestones in order. Each milestone has a concrete exit gate. Do not optimize the Coverage model while the rollout contract is still unstable.

### M0 — Freeze the baseline and make the workspace reproducible

**Goal.** Create one known-good robotics environment that can be recreated from repository state instead of manual machine history.

**Work steps**
1. **Create the cloud GPU host.** Start with an RTX A6000/L40-class 48 GB RT-capable GPU, Linux, adequate RAM and persistent storage.
2. **Create persistent directories.** Create host folders for models, datasets/eval, caches and experiment outputs before building the Arena container.
3. **Clone and pin Arena.** Clone IsaacLab-Arena, initialize submodules, then record the exact commit/release that will be used for the POC. Do not track a floating main branch after the first successful setup.
4. **Launch the supported environment.** Use Arena Docker (preferred for reproducibility) or the documented uv developer setup. Run the provided test subset including camera tests.
5. **Record the environment.** Export GPU model, driver, Docker version, container/image hash, Arena commit, Isaac Sim version and Isaac Lab version into `docs/environment.md`.
6. **Pin the `lerobot` package.** Record the exact `lerobot` version/commit used for dataset writing, and confirm whether it supports custom `meta/episodes.jsonl` fields or needs the `episode_manifest.parquet` fallback (see Section 3).

**Required outputs**
- [ ] A fresh shell can start the Arena container.
- [ ] Arena tests required for the selected workflow pass.
- [ ] Version manifest is committed, including the pinned `lerobot` version.
- [ ] Persistent model/eval directories survive container restart.

**Exit criteria**
- [ ] Another machine of the same class can reproduce the setup from the README without undocumented steps.

> Implementation note: Current Arena pre-release documentation pairs Isaac Sim 6.0.0 with Isaac Lab 3.0.0 and supports Docker. Pin the exact tested state rather than relying on "latest".

### M1 — Run the standard pick-and-place environment without the VLA

**Goal.** Verify the scene, DROID embodiment, cameras, reset loop and success logic before introducing the model server.

**Work steps**
1. **Load the environment.** Launch `pick_and_place_maple_table` with the DROID absolute-joint-position embodiment and the intended object/destination pair.
2. **Inspect observations.** Print/log joint state, EEF pose, object pose, target pose and camera availability for a small number of steps.
3. **Test resets.** Run repeated reset/step/terminate cycles and verify that seeds and randomization produce controlled, recorded initial states.
4. **Verify task outcome.** Confirm that Arena emits an episode success/failure outcome and identify where that outcome is exposed in code for logging.
5. **Save one debug episode.** Store metadata plus state traces even if the policy is zero-action; this validates the plumbing before VLA integration.

**Required outputs**
- [ ] Environment startup command is stored in `scripts/`.
- [ ] At least 10 automatic reset/run/terminate cycles complete.
- [ ] Object and target poses are recorded correctly.
- [ ] Outcome signal is programmatically accessible.

**Exit criteria**
- [ ] The environment can run repeatedly without manual UI actions or state leakage between episodes.

### M2 — Run GR00T closed loop and obtain real successes

**Goal.** Establish the System Under Test: GR00T controls DROID in Arena and completes the standard pick-and-place task often enough to generate both positive and negative episodes.

**Work steps**
1. **Start the GR00T policy server.** Use the documented GR00T N1.6-DROID server in a separate process. Allow the first model download to complete and persist the cache.
2. **Run Arena policy_runner.** Connect Arena to the remote closed-loop GR00T policy and use the documented language instruction for the selected object and bowl.
3. **Run a small batch.** Execute 20–30 episodes with fixed object/background first. Record Arena-reported success and visually inspect a small sample.
4. **Characterize baseline behavior.** Compute success rate, episode length distribution and common obvious failure modes. Do not tune Coverage yet.
5. **Decide whether this baseline is usable.** If there are zero successes, fix VLA/environment integration. If there are zero failures, introduce only mild supported variations rather than immediately switching robot/model.

**Required outputs**
- [ ] Command/script starts GR00T server.
- [ ] Command/script runs closed-loop episodes.
- [ ] At least several successful episodes are reproducibly observed.
- [ ] At least one failure mode can be produced naturally or by mild condition variation.

**Exit criteria**
- [ ] The team can run a batch unattended and get Arena success/failure for each episode.

> Implementation note: Arena documents GR00T N1.6-DROID as a pretrained closed-loop policy for `pick_and_place_maple_table`. This is why it is the recommended first System Under Test.

### M3 — Implement the rollout logger and freeze the dataset schema

**Goal.** Turn each Arena episode into a LeRobotDataset record that the Coverage environment can consume without importing Isaac.

**Work steps**
1. **Implement the LeRobot writer.** Use the LeRobotDataset writer API (`add_frame` per control step, `save_episode` at termination) instead of hand-rolled JSON/NPZ files.
2. **Log synchronized timestep data.** At each control step record timestamp, robot state, EEF, gripper, object/target state, contact, camera frames and exact action into the feature keys defined in Section 3.
3. **Write custom episode metadata.** At episode end, write success/termination-reason/seed/config fields via the mechanism confirmed in M0 (`meta/episodes.jsonl` custom fields or the `episode_manifest.parquet` fallback).
4. **Add schema validation.** Create `validate_episode.py` that checks: all required feature keys present, dimensions match `schemas/episode_schema.yaml`, monotonic timestamps, no NaNs, consistent episode length, and custom metadata fields present.
5. **Add replay/inspection utility.** Plot key signals from a saved episode and review the recorded video for manual QA.
6. **Version the schema.** Track LeRobot's own `codebase_version` (in `meta/info.json`) plus a project-level `schema_version` for the custom fields. Any field change after this point must increment or migrate the schema.

**Required outputs**
- [ ] One successful and one failed episode pass the validator.
- [ ] Coverage code can load both episodes on a machine with no Isaac installation, using only the `lerobot` Python package.
- [ ] A summary script reports episode count, outcomes, lengths and missing fields.
- [ ] Schema is documented and versioned.

**Exit criteria**
- [ ] 100 episodes can be generated and validated automatically with no manual file repair.

### M4 — Add physical-interaction sensing

**Goal.** Extend the rollout with contact signals so the new POC measures information that was not available in the original LIBERO setup.

**Work steps**
1. **Enable contact reporting.** Activate contact sensing on the relevant gripper/finger rigid bodies in the Isaac Lab scene configuration.
2. **Log net contact force.** Record the world-frame net force vector and its magnitude into the `observation.contact.net_force` feature key for each selected sensor body.
3. **Add filtered contact.** Where practical, filter contact against the manipulated object so object-contact can be separated from table/background contact, and write it to `observation.contact.filtered_force`.
4. **Define `observation.contact.active`.** Choose and document a force threshold; keep the raw force in the dataset so the threshold can be changed offline. Keeping contact as separate feature keys (not packed into a state vector) means this threshold can be revisited without touching other features.
5. **Optional richer signals.** If stable in the selected version, add contact point position and friction force. Treat these as optional fields, not blockers.
6. **Sanity-test signals.** Inspect episodes containing approach, grasp, lift and release. Contact must appear at physically plausible times and must not be permanently active due to misconfiguration.

**Required outputs**
- [ ] Contact vector/magnitude appears in every timestep.
- [ ] Filtered object-contact works or is explicitly documented as unsupported for the chosen sensor arrangement.
- [ ] Plots show sensible contact onset around grasp/release.
- [ ] Schema validator checks contact fields.

**Exit criteria**
- [ ] Contact traces are trustworthy enough to use as model features.

> Implementation note: Isaac Lab ContactSensor reports net contact force and supports filtered force reporting; current docs also expose contact points and friction-force tracking. Start with net force because it is the simplest robust signal.

### M5 — Generate the first controlled rollout dataset

**Goal.** Produce enough successful and failed episodes to train a success-only baseline and test generalization under controlled variation.

**Work steps**
1. **Define a condition manifest.** List every parameter allowed to vary and its train/test range before generating the large batch.
2. **Start with position variation.** Randomize object X/Y and yaw over a bounded range while keeping model, task and robot fixed.
3. **Add one variation dimension at a time.** After position is stable, vary object asset or background/lighting; later add physical parameters such as friction/mass if exposed reliably.
4. **Generate successes for training.** Build a train/calibration set containing only successful trajectories. Keep all failures out of success-only model fitting.
5. **Generate mixed evaluation episodes.** Create a held-out evaluation set with both successes and failures and untouched seeds.
6. **Run dataset QA.** Check distribution of initial conditions, outcome rate, lengths, contact statistics and duplicate seeds/configurations.

**Required outputs**
- [ ] Condition manifest is committed.
- [ ] At least 300 validated episodes for the first pass; target 500–1,000 once stable.
- [ ] Training split contains success only.
- [ ] Calibration/evaluation splits are frozen by episode ID.
- [ ] Dataset summary report is generated automatically.

**Exit criteria**
- [ ] The dataset contains enough failures to estimate recall/false alarms and enough successes to calibrate a threshold.

> Implementation note: Do not chase a specific episode count if the policy almost never fails or almost never succeeds. First adjust controlled conditions to create a useful operating region.

### M6 — Reproduce the Coverage baseline on the new state space

**Goal.** Re-establish the LIBERO idea with minimal novelty: learn expected future dynamics from successful trajectories and use prediction error as the anomaly signal.

**Work steps**
1. **Select feature keys and build the feature vector.** Start with `observation.robot.*`, `observation.eef.pose`, `observation.gripper`, `observation.object.*`, `observation.target.pose`. Leave `observation.contact.*` and `observation.images.*` out of this baseline's feature-key list.
2. **Normalize using training successes.** Fit all scalers/normalizers on the training-success split only.
3. **Create temporal samples.** Construct `(x_t, action sequence, x_{t+k})` samples with horizons expressed in both steps and seconds.
4. **Train a simple predictor first.** Use a linear/MLP or small temporal model before introducing a large architecture. The purpose is to test the signal, not model capacity.
5. **Calibrate the anomaly threshold.** Use a held-out success calibration set to set a false-alarm operating point.
6. **Score full episodes.** Produce a per-timestep score and store it separately from the raw episode dataset.

**Required outputs**
- [ ] Reproducible train command and config.
- [ ] Saved model + normalizer + threshold.
- [ ] Per-timestep score for all evaluation episodes.
- [ ] Success and failure score traces can be plotted against task events.

**Exit criteria**
- [ ] A held-out failure set shows whether prediction error separates at least some failures before termination.

### M7 — Test whether contact improves early failure prediction

**Goal.** Measure the value of physical-interaction information rather than merely adding more features.

**Work steps**
1. **Define Model A.** Same feature-key list as M6: state + object/target + actions, no `observation.contact.*`.
2. **Define Model B.** Same pipeline, config and model capacity as Model A, with `observation.contact.net_force` / `observation.contact.filtered_force` added to the feature-key list. Because contact is a separate LeRobot feature key, this is a one-line config change, not a re-export of the dataset.
3. **Keep splits identical.** Both models must train/calibrate/evaluate on exactly the same episode IDs.
4. **Measure event alignment.** For failures involving bad grasp, slip or drop, inspect whether contact deviations appear before the terminal event.
5. **Compare operating points.** Compare recall at fixed false-alarm rate and median lead time, not only AUROC.
6. **Document failure subtypes.** Even if labels are heuristic, group obvious grasp/drop/timeout failures to understand where contact helps.

**Required outputs**
- [ ] Ablation report with identical splits.
- [ ] Recall, precision, false alarms, AUROC/AUPRC and lead-time metrics.
- [ ] Representative timeline plots with alert time and failure time.
- [ ] Conclusion: where contact helps, where it does not, and confidence level.

**Exit criteria**
- [ ] The team can answer whether physical interaction adds measurable early-warning value.

### M8 — Move from failure prediction toward a coverage map

**Goal.** Demonstrate the first Coverage Engine behavior: reliability is measured across regions of an explicit condition space, not only across pooled episodes.

**Work steps**
1. **Define a small condition grid.** Example: object X/Y bins × yaw bins × object type, with the number of dimensions kept intentionally small.
2. **Run balanced evaluation.** Collect enough episodes per cell to estimate task success and alert behavior.
3. **Aggregate by cell.** For each cell compute success rate, failure count, warning recall, false alarms and lead time.
4. **Visualize the map.** Produce heatmaps/tables showing where the VLA is reliable and where the Coverage Engine identifies weak regions.
5. **Mark unsupported regions.** Do not extrapolate empty cells. Explicitly distinguish tested, sparse and untested regions.
6. **Create the Phase-1 report.** Summarize system setup, dataset, predictive results, contact ablation, coverage map and limitations.

**Required outputs**
- [ ] Condition-space definition is versioned.
- [ ] Per-cell outcome and Coverage metrics are available.
- [ ] Coverage visualization distinguishes tested vs untested space.
- [ ] Final report states go/no-go for the next phase.

**Exit criteria**
- [ ] The POC demonstrates both episode-level early warning and condition-level reliability structure.

---

## 5. Evaluation protocol

### Primary metrics

| Metric | What it tells us |
|---|---|
| Failure recall | Fraction of failed episodes for which an alert is raised before the defined failure time. |
| False-alarm rate | How often successful episodes are alerted, measured per episode and optionally per unit time. |
| Precision | Fraction of alerts that occur on failed episodes. |
| Lead time | `t_failure - t_alert`. Report median and distribution; negative/zero values are not early warnings. |
| AUROC / AUPRC | Useful summary metrics, but secondary to operating-point behavior. |
| Success score stability | Score distribution on successful trajectories, including peaks during normal contact events. |

### Failure time

Do not automatically equate episode termination with the moment the failure becomes irreversible. For obvious failures, log or derive a task event when possible: object lost from gripper, object falls below a height threshold, timeout becomes inevitable, or final placement violation. Always report the definition used.

### Minimum experiment matrix

| ID | Experiment | Purpose |
|---|---|---|
| E0 | Sanity | Same distribution as success training; verify that the signal exists. |
| E1 | Position shift | Train/calibrate in one pose range, test in held-out pose bins. |
| E2 | Object variation | Test one or more held-out object assets if GR00T can act on them. |
| E3 | Contact ablation | Model A vs B on identical splits. |
| E4 | Coverage grid | Aggregate metrics by condition cell. |

---

## 6. Practical runbook

### When Environment A is started

- [ ] Confirm GPU/driver and persistent mounts.
- [ ] Start the Arena container.
- [ ] Start GR00T server and wait until the model is loaded.
- [ ] Run a 1-episode smoke test.
- [ ] Run the requested batch headless/automated.
- [ ] Validate all episodes before shutting the GPU down.
- [ ] Copy/sync episode manifest and logs to persistent/shared storage.
- [ ] Stop the expensive instance.

### When working in Environment B

- [ ] Pull only the rollout dataset + schema + Coverage repository.
- [ ] Run schema validation and dataset summary first.
- [ ] Freeze episode split manifests before training.
- [ ] Train baseline from config; do not edit raw episodes.
- [ ] Store derived features/scores separately from raw rollout data.
- [ ] Generate metrics and plots from saved scores so analysis is repeatable.

### Debugging order

1. **Environment does not launch.** Fix Isaac/Arena installation before touching GR00T.
2. **Environment runs but VLA fails every time.** Validate camera/instruction/embodiment/action mapping and reproduce NVIDIA baseline exactly.
3. **VLA works but logs are inconsistent.** Stop dataset generation and repair the logger/schema.
4. **Contact looks implausible.** Fix sensor bodies/filter/threshold before model training.
5. **Coverage model has no signal.** First verify split leakage, normalization, horizons and score alignment; only then increase model complexity.
6. **No meaningful failures in test.** Change controlled conditions, not the model.

---

## 7. Go / No-Go criteria for the next floor

The next floor is to replace privileged object state progressively with information derived from sensors/pixels. Do not move there simply because the simulator runs.

**GO if**
- [ ] The rollout pipeline is reproducible and independent of manual UI steps.
- [ ] The dataset contract is stable and Coverage runs without Isaac installed.
- [ ] There is measurable early-warning signal on held-out failures at an acceptable false-alarm operating point.
- [ ] Contact ablation gives a clear answer, positive or negative.
- [ ] A small condition-space coverage map reveals tested reliable/weak regions rather than only one pooled number.

**NO-GO / repair first if**
- [ ] Success/failure labels are unreliable.
- [ ] Failure time cannot be aligned well enough to claim early prediction.
- [ ] Data logging changes from batch to batch.
- [ ] The predictor only distinguishes terminal states after the failure has already happened.
- [ ] Results depend on random leakage between very similar episodes.

---

## 8. Reference commands

These are starting commands from the current Arena documentation. Copy them into repository scripts and pin the tested commit before treating them as production runbooks.

**Arena install (Docker)**
```bash
git clone git@github.com:isaac-sim/IsaacLab-Arena.git
cd IsaacLab-Arena
git submodule update --init --recursive
./docker/run_docker.sh
```

**GR00T policy server**
```bash
cd submodules/Isaac-GR00T
uv run python gr00t/eval/run_gr00t_server.py \
  --model-path nvidia/GR00T-N1.6-DROID \
  --embodiment-tag OXE_DROID
```

**Closed-loop pick-and-place**
```bash
python isaaclab_arena/evaluation/policy_runner.py \
  --viz kit \
  --policy_type isaaclab_arena_gr00t.policy.gr00t_remote_closedloop_policy.Gr00tRemoteClosedloopPolicy \
  --policy_config_yaml_path isaaclab_arena_gr00t/policy/config/droid_manip_gr00t_closedloop_config.yaml \
  --remote_host 127.0.0.1 --remote_port 5555 \
  --language_instruction "Pick up the Rubik's cube and place it in the bowl." \
  --enable_cameras --num_episodes 3 \
  pick_and_place_maple_table \
  --embodiment droid_abs_joint_pos \
  --pick_up_object rubiks_cube_hot3d_robolab \
  --destination_location bowl_ycb_robolab \
  --hdr home_office_robolab
```

---

## 9. Sources used to refresh this plan

- Isaac Lab-Arena — GR00T closed-loop workflow: https://isaac-sim.github.io/IsaacLab-Arena/main/pages/quickstart/first_experiments/running_a_real_policy/gr00t.html
- Isaac Lab-Arena — installation / current pre-release compatibility: https://isaac-sim.github.io/IsaacLab-Arena/release/0.3.0-prerelease/pages/quickstart/installation.html
- Isaac Lab-Arena — external repository integration: https://isaac-sim.github.io/IsaacLab-Arena/release/0.2.1/pages/arena_in_your_repo/external_installation.html
- Isaac Lab — Contact Sensor: https://isaac-sim.github.io/IsaacLab/main/source/overview/core-concepts/sensors/contact_sensor.html
- Isaac Lab — Docker / Cloud: https://isaac-sim.github.io/IsaacLab/develop/source/features/docker_cloud.html
- Isaac Sim — requirements: https://docs.isaacsim.omniverse.nvidia.com/latest/installation/requirements.html
- RunPod — GPU pricing: https://www.runpod.io/pricing
- LeRobot — dataset format and library: https://github.com/huggingface/lerobot

> **Final principle.** Keep the expensive simulator/VLA stack replaceable. The durable product boundary is: any robotics test system produces a versioned rollout dataset; Coverage Engine consumes that dataset and produces early-warning and coverage evidence.
