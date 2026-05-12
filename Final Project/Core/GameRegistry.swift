//
//  GameRegistry.swift
//  Final Project
//
//  Central registry of all available games.
//  To add a new game, just append a GameInfo entry here.
//

import SwiftUI

// MARK: - Game Info

struct TutorialSection: Sendable {
    let heading: String
    let body: String
}

struct TutorialContent: Sendable {
    let overview: String
    let sections: [TutorialSection]
}

struct GameInfo: Identifiable {
    let id = UUID()
    let title: String
    let icon: String          // SF Symbol name
    let gameType: String      // unique identifier
    let createEngine: () -> any GameEngine
    let tutorial: TutorialContent
}

// MARK: - Game Registry

struct GameRegistry {
    /// All games available on the platform.
    /// To add a new game: implement GameEngine protocol, then add one line here.
    static let availableGames: [GameInfo] = [
        GameInfo(
            title: ReversiEngine.gameTitle,
            icon: ReversiEngine.gameIcon,
            gameType: ReversiEngine.gameType,
            createEngine: { ReversiEngine() },
            tutorial: TutorialContent(
                overview: "在 8×8（或自選 6–12 路）棋盤上翻轉對手棋子，遊戲結束時占多數者獲勝。",
                sections: [
                    TutorialSection(heading: "目標",
                        body: "讓棋盤上你的顏色棋子比對手多。當雙方都無法落子時遊戲結束。"),
                    TutorialSection(heading: "落子規則",
                        body: "落子必須「夾住」對手至少一顆棋子——被夾住的對手棋子（在同一直線上、兩端都是你的棋子）全部翻為你的顏色。"),
                    TutorialSection(heading: "跳過回合",
                        body: "若本回合無合法落子位置，回合自動跳過並提示。雙方都無法落子時遊戲結束。"),
                    TutorialSection(heading: "勝負判定",
                        body: "棋盤填滿或雙方都無法落子時計分，棋子多者獲勝；相同則平手。"),
                    TutorialSection(heading: "棋盤大小",
                        body: "支援 6×6、8×8、10×10、12×12，由房主在開局前設定，設定會同步給對手。")
                ]
            )
        ),
        GameInfo(
            title: GomokuEngine.gameTitle,
            icon: GomokuEngine.gameIcon,
            gameType: GomokuEngine.gameType,
            createEngine: { GomokuEngine() },
            tutorial: TutorialContent(
                overview: "在棋盤上搶先連成五顆同色棋子（橫、直、斜任一方向）即獲勝。",
                sections: [
                    TutorialSection(heading: "目標",
                        body: "率先在任意方向連成五顆棋子（不多不少恰好五顆，或超過亦可，視禁手設定而定）。"),
                    TutorialSection(heading: "落子規則",
                        body: "點擊棋盤交叉點落子；長按可精準選格。先出現預覽棋，確認按鈕才正式落下，防止誤觸。"),
                    TutorialSection(heading: "三三禁手",
                        body: "黑方一步棋同時形成兩條「活三」（兩端皆空的連三）則禁止落子。"),
                    TutorialSection(heading: "四四禁手",
                        body: "黑方一步棋同時形成兩條「活四」（兩端皆空的連四）則禁止落子。"),
                    TutorialSection(heading: "長連禁手",
                        body: "黑方形成超過五顆連子則禁止落子（六連以上）。"),
                    TutorialSection(heading: "禁手設定",
                        body: "三三、四四、長連可分別開關，並指定套用於黑方、白方或雙方。由房主設定後同步。"),
                    TutorialSection(heading: "棋盤大小與縮放",
                        body: "支援 15–25 路棋盤。可用雙指縮放或底部按鈕調整棋盤大小。")
                ]
            )
        )
    ]
}
