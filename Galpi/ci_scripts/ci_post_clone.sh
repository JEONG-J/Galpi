#!/usr/bin/env bash
#
#  ci_post_clone.sh
#  Galpi
#
#  Created by euijjang97 on 9/2/26.
#
#  Xcode Cloud 가 레포를 클론한 직후 실행하는 스크립트.
#  이 레포는 Tuist 기반이라 .xcodeproj / .xcworkspace 가 gitignore 대상이므로
#  여기서 mise(= tuist 버전 고정) 설치 → tuist install → tuist generate 까지 마쳐야
#  Xcode Cloud 가 빌드할 워크스페이스를 찾을 수 있다.
#

set -euo pipefail

# ci_scripts/ 의 부모 = Galpi/ (mise.toml · Makefile 위치)
cd "$(dirname "$0")/.."

# Xcode Cloud 러너에는 mise 가 없다 → 공식 설치 스크립트로 ~/.local/bin 에 설치
if ! command -v mise >/dev/null 2>&1; then
  echo "▶︎ mise 설치"
  curl -fsSL https://mise.run | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

make bootstrap   # mise trust + mise install (mise.toml 이 tuist 버전 고정)
make install     # tuist install — SPM 의존성 해석
# Xcode Cloud 가 빌드마다 증가시키는 번호를 CFBundleVersion 으로 쓴다. 넘기지 않으면
# Settings+Recommended.swift 의 기본값 1 이 박혀, 같은 마케팅 버전의 두 번째
# TestFlight 업로드부터 빌드 번호 중복으로 거부된다.
# tuist generate --no-open — Galpi.xcworkspace 생성
TUIST_BUILD_NUMBER="${CI_BUILD_NUMBER:-1}" make generate

echo "▶︎ 생성된 워크스페이스:"
ls -d Galpi.xcworkspace
