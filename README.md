# Horse Heist · Roblox / Rojo

VS Code에서는 이 폴더(`C:\Users\전상우\Documents\Roblox`)를 엽니다.

## 게임 실행

1. Roblox Studio에서 기존 **말 게임** Place를 엽니다.
2. VS Code에서 `Tasks: Run Task → Rojo: Start server`를 실행합니다.
3. Studio Rojo 플러그인에서 `localhost:34872`에 연결합니다.
4. Play를 누르면 자신의 농장과 12칸 마구간이 배정됩니다.
5. 화면의 **농장주 목장 →** 버튼으로 NPC 농장 입구에 이동합니다.
6. 말 앞에서 **E키를 2초간 눌러** 훔칩니다. 모든 희귀도와 다른 플레이어의 말에 동일하게 적용됩니다. 상호작용 후 안전 구역으로 이동하며, 추가 훔치기 대기 없이 3초 출발 카운트다운을 진행합니다.
7. 추격에서는 **A/D 또는 방향키**로 레인 이동, **Space**로 점프, **S/아래쪽 방향키**로 슬라이딩합니다.
8. 탈출에 성공하면 말을 획득합니다. **내 말** 메뉴에서 배치·창고·보호 상태를 관리합니다.
9. 결과 화면에서 돌아오면 자신의 농장으로 복귀합니다.

연습 달리기는 마을 광장의 **연습 트랙**에서 E키로 시작합니다. 화면 왼쪽 아래의 말 선택 패널과
연습 안내 카드는 제거했습니다. 속도·체력 훈련은 유지되며, 농장 이동 버튼은 로비에서만 동작합니다.
개인 농장은 중앙 도로를 바라보며, 마구간 정면의 가운데 문과 도로가 진입로로 연결됩니다.

pull 후에는 Rojo 연결을 확인하고 Studio 테스트를 완전히 중지한 뒤 다시 Play를 시작하세요.
UI, 실행 중인 스크립트와 캐시된 모듈, 농장 배치는 새 테스트에서 갱신됩니다.
NPC 목장의 말은 브론즈/실버/골드/챔피언/로얄/레전드 확률 45/28/15/8/3/1로 생성됩니다.
높은 등급일수록 입자와 테두리 효과가 강해지고 장식이 추가됩니다. 탈취된 NPC 말 슬롯은 60초 뒤 보충됩니다.

## 파일과 Studio 매핑

## 2026-09-09 추격·점프·리스폰 테스트

- `Shared/GuardConfig`: 농장주 추격 속도 18 → 초당 1.5 증가 → 최대 38 studs/s. 기존 Shift 질주 35보다 조금 빠르게 제한한다. 경비견은 기존 추격 속도 32를 유지한다. 시야를 놓치거나 농장을 벗어나 추격이 끝나면 가속이 초기화된다.
- `Client/GuardVisuals`: 서버의 탐지·포획 판정은 유지하고 화면용 NPC를 매 프레임 보간한다. 경비견의 순찰은 칸막이 안쪽 대신 열린 앞마당을 이용한다.
- 테스트 시야: 초록색은 순찰, 빨간색은 추격, 노란색은 농장 경계다. 표시되는 부채꼴은 65 studs / 110° 시야의 지상 투영이며 벽과 농장 경계에서 잘린다. 실제 탐지는 서버의 높이·시선 검사도 적용하므로 표시선은 판정의 근사치다. 카메라에서 220 studs 이내 NPC에 표시한다.
- 표시를 끄려면 `src/shared/GuardConfig.luau`의 `ShowDetectionRange=false`로 변경한다. 실행 중에는 Workspace의 `GuardDebugEnabled` Boolean 속성으로 표시를 전환할 수 있다.
- NPC 말 달리기 추격도 시간이 지나면 거리가 줄어든다. 농장주는 해당 말의 기본 속도보다 0.6 느리게 출발하고, 3초 후부터 초당 0.06씩 가속한다. 상한은 말 기본 속도 +0.4, 절대 상한 64다. 말의 속도 능력과 사람끼리의 PvP 추격은 유지한다.
- 점프 참고 영상: https://www.youtube.com/shorts/iJVQSGEETLQ (약 3초의 직립 동작). 몸통을 90° 세우고 앞발을 팔처럼 벌리는 자세를 공중에서 유지한 뒤 네 발 자세로 돌아온다. 기존 점프 높이·시간·2단 점프 능력·슬라이딩·탑승자를 유지한다.
- 리스폰 대기시간은 `HorseRun/Config.RespawnSeconds=2`. 개인 농장에 전용 SpawnLocation을 지정하고, 달리기 화면은 사망 시 먼저 숨긴 뒤 여러 프레임에 나누어 정리한다. 농장 건축물을 리스폰마다 다시 만들지 않는다.
- 수정 후 Studio의 기존 Play를 중지하고 다시 시작해야 캐시된 모듈이 갱신된다. 맵·마구간 배치와 말 원본 에셋은 변경하지 않았다.

### 검증 코드

`tests/GameplayRegression.luau`와 `tests/ChaseMotionRegression.luau`는 Studio 테스트 데이터모델에서 실행하는 함수다. 농장 좌표, 당근 중복 보상 방지, 입력 제한, 직립 점프·탑승자, 가속 상한, 보간 및 프레임률 독립성을 검사한다. 운영 저장 데이터를 쓰지 않는다.

## 파일과 Studio 매핑 (상세)

이 프로젝트는 여전히 **Partially Managed Rojo**입니다. 이번 게임 수정에 필요한 기존 코드를
Studio에서 읽어 원래 경로 그대로 파일 관리 대상으로 편입했습니다. 맵·말 원본 모델·Terrain·Lighting을
Rojo 프로젝트 트리에 통째로 매핑하지 않습니다.

| 파일 위치 | Studio 위치 |
| --- | --- |
| `src/client/` | StarterPlayer → StarterPlayerScripts → Client |
| `src/server/` | ServerScriptService → Server |
| `src/shared/` | ReplicatedStorage → Shared |
| `src/horse-run/` | ReplicatedStorage → HorseRun |
| `src/entry/HorseRunClient.client.luau` | StarterPlayer → StarterPlayerScripts → HorseRunClient |
| `src/entry/HorseRunServer.server.luau` | ServerScriptService → HorseRunServer |

`*.server.luau`는 Script, `*.client.luau`는 LocalScript, 일반 `*.luau`는 ModuleScript입니다.
관리 루트의 `$ignoreUnknownInstances: true`는 매핑되지 않은 자식을 보존합니다.
이미 관리 중인 스크립트의 Source 수정·삭제는 동기화됩니다.
`HorseRun/Horses`의 말 원본 모델과 기존 RemoteEvent는 Studio에 남아 있어야 합니다.

주요 수정 위치:

- `Horse.luau`: 위상 연속 달리기, 점프, 착지, 슬라이딩 변형.
- `VisualRig.luau`: 말 복제본의 관절 연결과 파츠 변형. 원본 에셋은 수정하지 않습니다.
- `Characters.luau`: 탑승 아바타와 테스트용 농부. R6/R15 및 AnimationConstraint 관절 대응.
- `FarmVisual.luau`: 넓은 마을, NPC 목장, 개인 마구간, 희귀도 효과.
- `NpcFarmService.server.luau`: NPC 말 생성·훔치기·보충.
- `PlayerFarm.luau`: 개인 농장 배정, 전시, 기존 보호/훔치기 처리.
- `HorseRunClient.client.luau`: 화면, 입력, 추격 농부, 카메라.
- `HorseRunServer.server.luau`: 서버 판정, 획득, 귀환, 기존 소유권 처리.

맵 건물은 위 코드가 생성하므로 코드 변경은 Git에서 추적할 수 있습니다.
원본 말 모델·수작업 에셋과 Place 파일은 별도 Studio 저장이 필요합니다.
이 파일만으로 빈 Place에서 전체 게임을 재현하는 `rojo build` 구조는 아닙니다.

## 도구

Rokit **1.2.0**, Rojo **7.7.0**. `rokit.toml`에 Rojo 버전이 고정되어 있습니다.

```powershell
rokit --version
rojo --version
rojo sourcemap default.project.json
rojo serve default.project.json
```

현재 Codex 샌드박스에서는 Rokit의 rojo 실행 래퍼가 경로 오류를 반환할 수 있습니다.
이 경우 검증된 실제 실행 파일을 사용합니다.

```powershell
& "$env:USERPROFILE\.rokit\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe" serve default.project.json
```

VS Code 작업도 이 실제 실행 파일을 사용합니다. 버전을 올리면 작업 경로도 함께 갱신하세요.
서버가 이미 실행 중이면 중복 실행하지 말고, 종료할 때는 터미널에서 Ctrl+C를 누릅니다.

## 보존 및 백업

- 최초 Place 백업: `before-rojo-20260906.rbxl`, `maybehorse0.1.rbxl`.
- 이번 수정 직전 코드: `.tools/backups/visual-farms-20260907/scripts.json`.
- Studio 관련 코드·모델 백업: `ServerStorage/CodexBackups/VisualFarmFix_20260907`.
- 교체 전 HorseRunWorld 원본: `ServerStorage/CodexBackups/PreviousHorseRunWorld_<시간>/HorseRunWorld`.

새 맵은 완성한 뒤 배치하며 기존 HorseRunWorld는 삭제하지 않고 위 백업 폴더에 보관합니다.
Terrain, Lighting 및 관련 없는 Workspace 객체는 이번 수정 대상에서 제외했습니다.
기존 말 원본 모델과 수집·소유권 저장 형식은 유지했습니다.

Studio의 현재 변경 사항과 백업을 보존하려면 Play를 종료한 상태에서 Place를 저장하세요.
기존 .rbxl 백업을 덮어쓰지 말고 날짜를 넣은 새 파일로 저장하는 것이 좋습니다.
이번 작업은 Roblox 게시 또는 GitHub push를 수행하지 않습니다.

## Git

기존 `.git` 및 remote 설정을 유지합니다. `git status --short`로 변경 파일을 확인합니다.
`src/`, 프로젝트 설정, README는 Git에 포함합니다.
`*.rbxl`, `*.rbxlx`, `.tools/`, 로그는 기존 .gitignore에 따라 제외되므로 별도로 백업합니다.
Studio 실행이 `StudioTest` 모드이면 테스트 획득 데이터는 실제 운영 저장 데이터와 분리됩니다.

참고: [Rojo 프로젝트 형식](https://rojo.space/docs/v7/project-format/),
[Roblox AnimationConstraint](https://create.roblox.com/docs/reference/engine/classes/AnimationConstraint).
