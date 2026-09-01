# 갈피(Galpi) 1.0 — MVP 설계 문서

> 2026-08-28 브레인스토밍(superpowers:brainstorming, architectural 경로)에서
> 섹션별 승인을 거쳐 확정된 설계. 비주얼 상세는 [디자인 명세](MVP_갈피%201.0%20디자인%20명세_설계.md) 참고.

- 작성자: 제옹(euijjang97)
- 작성일: 2026-08-28

## 1. 개요

- **문제**: 인스타그램·카카오톡·유튜브 등에서 본 유용한 글/영상을 각 앱의 보관함이나
  애플 메모장에 흩어 저장하고 있어, 다시 찾지도 소비하지도 못한다.
- **App Statement**: "공유 시트에서 3초 만에 꽂아두고, 잊기 전에 다시 꺼내 보는 링크 보관함."
- **핵심 가치**: ① 저장이 빠르다(3초, 탭 2번) ② 저장한 것을 실제로 소비하게 만든다
  (미열람 추적 + 리마인드) ③ 카테고리로 한곳에서 관리한다.

## 2. 플랫폼 & 기술 스택

| 항목 | 결정 |
|---|---|
| 최소 지원 | iOS 26+ |
| UI | SwiftUI + `@Observable` |
| 저장 | SwiftData + CloudKit 자동 동기화 (서버·자체 계정 없음) |
| 원격 호출 | `LinkPresentation` 메타데이터 추출 하나뿐 — 네트워크 스택 없음 |
| 빌드 | Tuist (템플릿 유지), `make bootstrap` / `make open` / `make test` |

## 3. MVP 범위

**포함**: Share Extension 저장(출처 자동 인식 + 카테고리 제안) · 제목/썸네일 자동 추출 ·
조회 기록(횟수·마지막 열람) · 미열람 필터 + 로컬 푸시 리마인드 · 검색 · 메모 ·
홈 위젯(스몰·미디엄) · 즐겨찾기 · 아카이브 · 카테고리 관리 · 온보딩 1~2장

**비포함 (비범위)**: 서버/자체 계정 · 링크 본문 스크랩/오프라인 저장 · 태그(카테고리로 충분) ·
공유/협업 · 열람 이력 타임라인 · Watch 타겟 · 통계 대시보드

## 4. 아키텍처 접근 — "템플릿 다이어트" (접근안 B 확정)

Tuist 모듈 구조 + Clean Architecture + `@Observable` 컨벤션은 유지하되, 서버 전용 요소를 삭제한다.

**템플릿에서 삭제**:
- Network/Moya 모듈 전체 — 원격 호출이 `LinkPresentation` 하나라 UseCase 아래 작은 서비스로 충분
- CLAUDE.md 절대 규칙 #2(서버 정수 String 통일) · #3(custom Codable) — 서버 응답이 없으므로
- Watch 타겟, Firebase·카카오/Google OAuth 관련 키·설정

**템플릿에서 유지**:
- `@Observable` ViewModel · DIContainer Protocol 주입 · AppRouter + Feature Router
- `Loadable` / `ErrorHandler` / `AlertPrompt` 에러 패턴 · 코딩 스타일 전부

**구조상 유일한 축약**: SwiftData `@Model`을 도메인 모델로 겸용한다 (Domain↔Data 매핑 계층 생략).
서버 DTO가 없는 앱에서 매핑은 순수 보일러플레이트이기 때문. 단 Repository Protocol 뒤에
SwiftData를 숨기는 경계는 유지 — 나중에 서버가 생기면 그 지점에서 분리한다.

## 5. 도메인 모델 (SwiftData `@Model` 2개)

### `Link` (갈피 하나)

| 필드 | 타입 | 비고 |
|---|---|---|
| `id` | UUID | |
| `urlString` | String | 원본 공유 URL |
| `title` | String? | LinkPresentation 자동 추출 |
| `thumbnailData` | Data? | 추출 썸네일 (다운샘플 저장) |
| `sourceApp` | String | URL 호스트로 판별 (`youtube`/`instagram`/`kakao`/`web`…) — 배지·필터용 |
| `memo` | String? | 공유 시트에서도 입력 가능 |
| `createdAt` | Date | |
| `viewCount` | Int = 0 | 조회 횟수 |
| `lastViewedAt` | Date? | **nil = 미열람** — 미열람 필터·알림·위젯이 전부 이 필드로 동작 |
| `isFavorite` | Bool = false | 즐겨찾기 |
| `isArchived` | Bool = false | 아카이브 |
| `category` | Category? | 관계. **nil = "받은함"(미분류)** |

### `Category`

`id: UUID` · `name: String` · `colorName: String` · `iconName: String` ·
`sortOrder: Int` · `createdAt: Date` (+ `links` 역관계)

### 결정 사항

- **CloudKit 제약 준수**: 전 프로퍼티 optional 또는 기본값, `.unique` 금지, 관계 optional.
- **열람 이력 테이블 없음** — "몇 번·언제 봤나"는 `viewCount` + `lastViewedAt`으로 충분.
  열람 타임라인 기능이 생기면 그때 추가.
- **"봤다" 판정**: 앱에서 링크를 탭해 여는 순간 `viewCount += 1`, `lastViewedAt = now`.
  별도 읽음 버튼 없음 (수동 읽음/안읽음 토글은 컨텍스트 메뉴에만).
- **받은함은 가상 카테고리** (`category == nil`) — 삭제·이름변경 불가, 마이그레이션 불필요.
- **중복 판정 기준**: `urlString` 문자열 완전 일치(쿼리 포함).
  <!-- ponytail: URL 정규화(트래킹 파라미터 제거 등)는 중복 누락이 실사용에서 확인되면 추가 -->

## 6. 모듈 구조 & 타겟

```
Workspace: Galpi
├── Galpi               (앱)
├── GalpiShareExtension (공유 시트 저장 UI)
├── GalpiWidget         (홈 위젯)
│
├── Core/GalpiFoundation    — App Group ID·딥링크 스킴 상수, 공용 유틸
├── Core/GalpiDesignSystem  — 디자인 토큰·공용 컴포넌트 (앱·확장 공용)
├── Core/GalpiKit           — 3개 타겟이 전부 의존하는 심장:
│     ├── @Model Link · Category (SwiftData)
│     ├── ModelContainer 팩토리 (App Group 경로 + CloudKit 설정)
│     ├── LinkRepository (Protocol + SwiftData 구현)
│     ├── UseCase (저장 · 열람 기록 · 미열람 조회 · 카테고리 관리)
│     ├── LinkMetadataService (LinkPresentation 제목/썸네일 추출)
│     ├── SourceApp 판별 (URL 호스트 → youtube/instagram/…)
│     └── ReminderScheduler (미열람 로컬 알림 계산·등록)
│
└── Features (Presentation 전용, 앱만 의존)
      ├── LinkBox   — 보관함 홈 · 카테고리 · 검색 · 링크 편집/메모
      └── Settings  — 알림 주기 · 카테고리 관리 · 정보
```

- 3개 타겟은 **App Group**으로 SwiftData 컨테이너를 공유한다.
- Share Extension은 GalpiKit + DesignSystem만 의존, 자체 UI는 저장 카드 하나 — Features 비의존.

## 7. 핵심 플로우

### ① 공유 저장 (목표: 3초, 탭 2번)

```
유튜브/인스타 공유 시트 → "갈피" 선택
→ 저장 카드 시트:
   [썸네일·제목 로딩중…] [출처 배지: YouTube]
   [카테고리 칩: 최근 사용 순, 마지막 쓴 카테고리 자동 선택]
   [메모 (선택)]
   [저장]
```

- **저장은 메타데이터를 기다리지 않는다** — URL + 출처만으로 즉시 insert.
  제목/썸네일은 확장에서 ~3초 타임아웃으로 시도, 실패 시 본앱 진입 때 백필.
- **중복 감지**: 같은 URL이 이미 있으면 "이미 보관된 링크예요" 표시 후
  새로 만들지 않고 기존 항목의 카테고리/메모만 갱신.
- 저장 완료 시 `WidgetCenter.reloadAllTimelines()`.

### ② 열람

- 리스트 탭 → 인앱 `SFSafariViewController`. 여는 순간 `viewCount += 1`, `lastViewedAt = now`.
- 컨텍스트 메뉴: 원본 앱에서 열기(OS 라우팅) · 읽음/안읽음 토글 · 즐겨찾기 ·
  카테고리 이동 · 아카이브 · 링크 복사 · 삭제(AlertPrompt).
- 셀에 열람 정보 노출: 미열람 = 파란 점, 열람 = "3회 · 2일 전".

### ③ 미열람 리마인드

- 콘텐츠 예: *"안 읽은 갈피 5개가 기다려요 — 「SwiftUI 성능 최적화」 외 4개"*
- 설정: 주기(매일/3일/매주/끄기, 기본 3일) + 시간(기본 21:00) + 앱 배지 토글.
- 등록: **앱이 백그라운드로 갈 때마다** ReminderScheduler가 미열람 개수를 계산해
  다음 알림을 재등록. `BGAppRefresh`로 주기 보정(best effort). 미열람 0개면 미등록.
- 알림 탭 → `galpi://unread` 딥링크 → 미열람 필터 화면.

### ④ 위젯

- 스몰: 미열람 개수. 미디엄: 미열람 개수 + 최근 저장 2~3개(썸네일·제목).
- 탭 딥링크: `galpi://unread`, `galpi://link/{id}`.

## 8. 에러 처리 (템플릿 패턴 적용)

| 상황 | 패턴 |
|---|---|
| 보관함/검색 로딩 | `Loadable` — 로컬 DB라 실패 드묾, 빈 상태 디자인이 더 중요 |
| 메타데이터 추출 실패 | 에러 아님 — 도메인명만 표시("youtube.com"), 편집 시트에서 재시도 가능 |
| iCloud 미로그인 | 앱은 로컬로 정상 동작, 설정에 동기화 상태 행 표시 (전역 Alert 금지) |
| 삭제 (링크·카테고리) | `AlertPrompt` — 카테고리 삭제 시 소속 링크는 받은함으로 이동 |
| 알림 권한 거부 | 리마인드 켤 때 요청, 거부 시 설정 앱 이동 안내 |

## 9. 화면 IA — 탭 없이 홈 단일 스택

링크 소비가 목적이므로 리스트 중심 단일 스택. 탭바 없음.

| # | 화면 | 내용 |
|---|---|---|
| ① | 보관함 홈 | 리스트 + 상단 필터 칩(전체·미열람·즐겨찾기·받은함·카테고리들) + `.searchable` 검색 + 아카이브 진입 + 설정 진입 |
| ② | 저장 카드 | Share Extension 시트 (플로우 ①) |
| ③ | 링크 편집 시트 | 메모 · 카테고리 변경 · 정보(조회 3회 · 2일 전 · 저장일 · 출처) — 별도 상세 화면 없이 이 시트가 겸용 |
| ④ | 카테고리 관리 | 추가 / 이름·색·아이콘 / 순서 / 삭제 |
| ⑤ | 설정 | 알림 주기·시간·배지, iCloud 상태, 카테고리 관리, 정보 |
| ⑥ | 인앱 브라우저 | `SFSafariViewController` (시스템 UI) |
| ⑦ | 위젯 | 스몰 · 미디엄 |
| ⑧ | 온보딩 1~2장 | "공유 시트에서 갈피 켜는 법" — Share Extension 발견성이 이 앱의 생명이라 필수 |

## 10. 테스트 전략

- **GalpiKit 단위 테스트가 중심** (`make test`): SourceApp 호스트 판별 ·
  저장 UseCase 중복 감지 · ReminderScheduler 다음 알림 시각 계산 ·
  열람 기록 UseCase — in-memory `ModelContainer`로 검증.
- Share Extension·위젯·CloudKit 동기화는 시뮬레이터/실기기 수동 확인 (자동화 비용 대비 실익 없음).
- UI 테스트는 MVP 비범위.

## 11. 다음 단계

1. 이 문서 + 디자인 명세 사용자 검토
2. `/design` 캔버스에서 방향 시안 2~3개 → 선택 → 본 시안
3. superpowers:writing-plans로 구현 계획 작성 → 구현 착수
