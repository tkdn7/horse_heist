# 추격·농부·말 외형 수정 검증 (2026-09-10)

현재 Studio 편집본으로 Rojo 동기화를 확인하고 로컬 Play에서 검증했다. 소유권 테스트는 `StudioTest` 메모리 저장소와 음수 테스트 사용자 ID를 사용했다.

| 검증 파일 | 결과 |
| --- | --- |
| `tests/GameplayRegression.luau` | 통과: 농장 배치, 당근 중복 획득, 방향 전환·점프, 세 말 모델의 보행 시점과 슬라이딩 복귀 |
| `tests/ChaseMotionRegression.luau` | 통과: 추격 거리 유지, 시간에 따른 NPC 가속 제외, 10/60Hz 비교, 능력·점프 유지 |
| `tests/TheftInteractionRegression.luau` | 통과: 상호작용·복귀, 수평 쇠스랑의 손 고정, 머리·모자 1~1.35배 반복 확대와 원상복귀 |
| `tests/PvpRedesignRegression.luau` | 통과: 같은 말 성능, 당근 2/충돌 6 거리 패널티, 이후 거리 유지, 포기 참가자·사건 ID 검증, 농장 보호, 원본 외형 보존 |
| `tests/PvpSurrenderOwnershipRegression.luau` | 통과: 양쪽 참가자 × 대기/직접 추격/NPC 대리 추격 6가지 소유권 결과, 거래 재실행, 능력치 보존 |

화면으로 가로 쇠스랑, 커진 머리·모자, 추가 도형을 제외한 말을 확인했다. 테스트 알림과 추격 화면의 포기 버튼을 실제 클릭해 사건 ID가 서버로 전달되는 것을 확인했고, 포기 결과 화면도 점검했다. 이 UI 검증은 테스트 알림을 사용했다.

`rojo sourcemap default.project.json`과 `git diff --check`가 통과했다. 마지막 새 Play 실행에서는 오류 없이 서버·클라이언트가 시작됐다. 기존 `PlayerModule missing` 안내와 PC 이동·카메라 대체 경로는 계속 사용 중이다.

두 실제 클라이언트가 함께 하는 전체 훔치기 과정과 네트워크 지연 상황의 체감 검증은 미실시다. 더 사실적인 관절 모션용 스키닝 모델 제작도 이번 범위에 포함되지 않는다. 다음 모델 제작안은 [HorseMotionPlan.md](HorseMotionPlan.md)를 참고한다.
