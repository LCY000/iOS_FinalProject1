//
//  GameRegistry.swift
//  Final Project
//
//  Central registry of all available games.
//  To add a new game, just append a GameInfo entry here.
//

import SwiftUI

// MARK: - Game Info

struct TutorialSection: Identifiable, Sendable {
    let id = UUID()
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
        ),
        GameInfo(
            title: QuoridorEngine.gameTitle,
            icon: QuoridorEngine.gameIcon,
            gameType: QuoridorEngine.gameType,
            createEngine: { QuoridorEngine() },
            tutorial: TutorialContent(
                overview: "在 9×9 棋盤上率先走到對岸即獲勝。每回合可移動棋子或放置牆壁阻擋對手。",
                sections: [
                    TutorialSection(heading: "目標",
                        body: "黑方從北側出發走到第 9 行（最南），白方從南側出發走到第 1 行（最北）。"),
                    TutorialSection(heading: "棋子移動",
                        body: "每回合可往上下左右任一方向移動一格（無法穿越牆壁）。"),
                    TutorialSection(heading: "跳棋規則",
                        body: "若相鄰格有對手棋子，可跳過並落在其後方。若後方被牆或邊界阻擋，可改走側面兩格之一。"),
                    TutorialSection(heading: "放置牆壁",
                        body: "選擇「橫牆」或「縱牆」模式，點擊格線間的槽位放置 2 格長的牆壁。牆壁放置後不可移除。"),
                    TutorialSection(heading: "牆壁限制",
                        body: "每人最多 10 道牆，且不能讓任何一方完全無路可走（系統自動驗證）。"),
                    TutorialSection(heading: "視角",
                        body: "連線對戰時雙方各自看到自己在畫面下方出發，方向感與桌遊一致。")
                ]
            )
        ),
        GameInfo(
            title: CheckersEngine.gameTitle,
            icon: CheckersEngine.gameIcon,
            gameType: CheckersEngine.gameType,
            createEngine: { CheckersEngine() },
            tutorial: TutorialContent(
                overview: "在棋盤上以斜向移動和跳吃對手棋子，吃光或困住對手所有棋子即獲勝。",
                sections: [
                    TutorialSection(heading: "目標",
                        body: "吃掉對手所有棋子，或讓對手陷入無法移動的局面。"),
                    TutorialSection(heading: "棋子移動",
                        body: "普通棋只能朝自己的前進方向斜走一格到空格。"),
                    TutorialSection(heading: "跳吃",
                        body: "若斜前方有對手棋子且其後方空格，可跳過對手棋子將其吃掉。"),
                    TutorialSection(heading: "強制吃子",
                        body: "當有可吃子的走法時，必須選擇吃子，不能改走普通移動。"),
                    TutorialSection(heading: "連跳",
                        body: "吃子後若同一棋子還有繼續跳吃的機會，必須繼續跳，直到無路可跳。"),
                    TutorialSection(heading: "升王",
                        body: "棋子走到對岸最後一排即升為「王」，有金色星芒標示。連跳途中到達不升王。"),
                    TutorialSection(heading: "王的移動",
                        body: "美式：王可往四個斜向各走一格。國際：王可往四個斜向走任意距離（飛王）。"),
                    TutorialSection(heading: "美式 vs 國際",
                        body: "美式（8×8）：只要能吃就必須吃。國際（10×10）：必須選擇吃子數最多的路線；飛王可長距移動。")
                ]
            )
        )
    ]
}
