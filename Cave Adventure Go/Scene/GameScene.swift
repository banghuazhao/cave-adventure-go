//
//  GameScene.swift
//  Cave Treasure Hunt
//
//  Created by Banghua Zhao on 4/11/20.
//  Copyright © 2020 Banghua Zhao. All rights reserved.
//

import GameplayKit
import GoogleMobileAds
import Localize_Swift
import SpriteKit
import Then

enum GameState {
    case play, pause
}

struct PhysicsCatagory {
    static let Explorer: UInt32 = 0x1 << 1
    static let Ground: UInt32 = 0x1 << 2
    static let Wall: UInt32 = 0x1 << 3
    static let Score: UInt32 = 0x1 << 4
}

class GameScene: SKScene {
    var interstitial: GADInterstitialAd!

    var gameState = GameState.play

    var explorer = SKSpriteNode()
    var lava: SKSpriteNode!
    var botGround = SKSpriteNode()
    var topGround = SKSpriteNode()
    var beginMoving = false

    var gameStarted = false

    var died = Bool()
    var restartBTN = SKSpriteNode()

    // playble rect
    var playableRect: CGRect!
    var topLimit: CGFloat!
    var bottomLimit: CGFloat!

    var lastUpdateTimeInterval: TimeInterval = 0
    var deltaTime: TimeInterval = 0
    var gameTime: TimeInterval = 0.0

    var groundMoveTime: TimeInterval = 6
    var moveTime: TimeInterval = 6

    var stage1: Bool = true

    let soundGameOver = SKAction.playSoundFileNamed("explosion3.wav", waitForCompletion: false)

    // label

    var score: Double = 0 {
        didSet {
            scoreLabel.text = String(format: "%.1f", score)
            if let bestScore = UserDefaults.standard.value(forKey: Constants.UserDefaultsKeys.BEST_SCORE) as? Double {
                if score > bestScore {
                    UserDefaults.standard.set(score, forKey: Constants.UserDefaultsKeys.BEST_SCORE)
                }
            } else {
                UserDefaults.standard.set(score, forKey: Constants.UserDefaultsKeys.BEST_SCORE)
            }
        }
    }

    lazy var scoreLabel = SKLabelNode(fontNamed: "Helvetica-Bold").then { node in
        node.text = "0.0"
        node.fontColor = SKColor.white
        node.fontSize = 54
        node.zPosition = 100
        node.horizontalAlignmentMode = .left
        node.verticalAlignmentMode = .center
    }

    lazy var bestScoreLabel = SKLabelNode(fontNamed: "Helvetica-Bold").then { node in
        if let bestScore = UserDefaults.standard.value(forKey: Constants.UserDefaultsKeys.BEST_SCORE) as? Double {
            node.text = "\("Best Score".localized()): \(String(format: "%.1f", bestScore))"
        } else {
            node.text = "\("Best Score".localized()): \(String(format: "%.1f", 0.0))"
        }

        node.fontColor = SKColor.white
        node.fontSize = 54
        node.zPosition = 100
        node.horizontalAlignmentMode = .center
        node.verticalAlignmentMode = .center
    }

    // MARK: - didMove

    override func didMove(to view: SKView) {
        addObservers()
        gameState = .play
//        bannerView.isHidden = false
        playBackgroundMusic(filename: "background.mp3", repeatForever: true)

        createScene()
    }

    // MARK: - update

    override func update(_ currentTime: TimeInterval) {
        if gameState == .pause {
            isPaused = true
            return
        }

        if lastUpdateTimeInterval > 0 {
            deltaTime = currentTime - lastUpdateTimeInterval
        } else {
            deltaTime = 0
        }

        lastUpdateTimeInterval = currentTime

        if gameStarted == true {
            gameTime += deltaTime

            if died != true {
//                print("moveTime: \(moveTime)")
                if moveTime > 0.5 {
                    moveTime = 6.0 - gameTime / 30
                } else {
                    moveTime = 0.5
                }
                score = score + Double(size.width) * deltaTime / moveTime / 100
                updateStage()
            }

            if explorer.position.x <= -size.width * 0.5 + 200 {
                if died == false {
                    died = true
                    createBTN()
                    explorer.run(SKAction.sequence([
                        SKAction.move(by: CGVector(dx: 0, dy: -size.height), duration: 1.0),
                    ]))
                    explorer.physicsBody?.isDynamic = false
                    enumerateChildNodes(withName: "wallPair", using: ({
                        node, _ in

                        node.speed = 0
                        self.removeAllActions()
                    }))
                    enumerateChildNodes(withName: "ground", using: ({
                        node, _ in

                        node.speed = 0
                        self.removeAllActions()
                    }))
                    backgroundMusicPlayer.stop()
                    run(soundGameOver)
                }
            }
        }
    }

    // MARK: - touchesBegan

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if gameStarted == false {
//            bannerView.isHidden = true
            gameStarted = true
            scoreLabel.isHidden = false
            bestScoreLabel.isHidden = true
            if beginMoving == false {
                let distance = CGFloat(frame.width)
                let moveGround = SKAction.moveBy(x: -distance, y: 0, duration: moveTime)
                let removeGround = SKAction.removeFromParent()
                let moveAndRemove = SKAction.sequence([moveGround, removeGround])

                botGround.run(moveAndRemove)
                topGround.run(moveAndRemove)
            }

            beginMoving = true

            explorer.physicsBody?.affectedByGravity = true
            explorer.physicsBody?.allowsRotation = false
            explorer.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
            explorer.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 300))
            let trail = SKEmitterNode(fileNamed: "PlayerTrail")!
            trail.zPosition = 3
            trail.position = CGPoint(x: -100, y: 0)
            explorer.addChild(trail)

        } else {
            if died != true {
                explorer.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
                explorer.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 300))
            }
        }

        for touch in touches {
            let location = touch.location(in: self)

            if died == true {
                if restartBTN.contains(location) {
                    GADInterstitialAd.load(withAdUnitID: Constants.interstitialAdID, request: GADRequest()) { ad, error in
                        if let error = error {
                            print("Failed to load interstitial ad with error: \(error.localizedDescription)")
                            self.restartScene()
                            return
                        }
                        self.interstitial = ad
                        self.interstitial.fullScreenContentDelegate = self
                        if let ad = self.interstitial, let rootViewController = self.view?.window?.rootViewController {
                            ad.present(fromRootViewController: rootViewController)
                        } else {
                            print("interstitial Ad wasn't ready")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - didmove related

extension GameScene {
    // MARK: - createScene

    func createScene() {
        let playableMargin = sceneCropAmount() / 2.0
        let playableHeight = size.height - 2 * playableMargin
        playableRect = CGRect(x: 0, y: -playableHeight / 2,
                              width: size.width,
                              height: playableHeight)
        topLimit = playableRect.minY + playableRect.height
        bottomLimit = playableRect.minY

        physicsWorld.contactDelegate = self
        physicsWorld.gravity = CGVector(dx: 0, dy: -9.0)
        physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(x: 0, y: -playableHeight / 2, width: size.height, height: playableHeight))

        botGround = SKSpriteNode(imageNamed: "Ground")
        botGround.position = CGPoint(x: 0, y: bottomLimit + botGround.frame.height / 2 - 20)
        botGround.physicsBody = SKPhysicsBody(rectangleOf: botGround.size)
        botGround.physicsBody?.categoryBitMask = PhysicsCatagory.Ground
        botGround.physicsBody?.collisionBitMask = PhysicsCatagory.Explorer
        botGround.physicsBody?.contactTestBitMask = PhysicsCatagory.Explorer
        botGround.physicsBody?.affectedByGravity = false
        botGround.physicsBody?.isDynamic = false
        botGround.name = "ground"
        botGround.zPosition = 3
        addChild(botGround)

        topGround = SKSpriteNode(imageNamed: "Ground")
        topGround.zRotation = CGFloat.pi
        topGround.position = CGPoint(x: 0, y: topLimit - topGround.frame.height / 2 + 20)
        topGround.physicsBody = SKPhysicsBody(rectangleOf: topGround.size)
        topGround.physicsBody?.categoryBitMask = PhysicsCatagory.Ground
        topGround.physicsBody?.collisionBitMask = PhysicsCatagory.Explorer
        topGround.physicsBody?.contactTestBitMask = PhysicsCatagory.Explorer
        topGround.physicsBody?.affectedByGravity = false
        topGround.physicsBody?.isDynamic = false
        topGround.name = "ground"
        topGround.zPosition = 3
        addChild(topGround)

        explorer = SKSpriteNode(imageNamed: "Explorer")
        explorer.position = CGPoint(x: -explorer.frame.width, y: 0)
        explorer.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: explorer.size.width, height: explorer.size.height * 1 / 2))
        explorer.physicsBody?.categoryBitMask = PhysicsCatagory.Explorer
        explorer.physicsBody?.collisionBitMask = PhysicsCatagory.Ground | PhysicsCatagory.Wall
        explorer.physicsBody?.contactTestBitMask = PhysicsCatagory.Ground | PhysicsCatagory.Wall | PhysicsCatagory.Score
        explorer.physicsBody?.affectedByGravity = false
        explorer.physicsBody?.isDynamic = true
        explorer.zPosition = 2
        explorer.setScale(0.8)
        addChild(explorer)

        scoreLabel.position = CGPoint(
            x: size.width / 2 - 150,
            y: topLimit - 80)
        addChild(scoreLabel)

        scoreLabel.isHidden = true

        bestScoreLabel.position = CGPoint(
            x: size.width / 2 - 300,
            y: topLimit - 80)
        addChild(bestScoreLabel)

        lava = childNode(withName: "Lava") as! SKSpriteNode
        let emitter = SKEmitterNode(fileNamed: "Lava.sks")!
        emitter.particlePositionRange = CGVector(dx: 0, dy: size.height * 1.15)
        emitter.advanceSimulationTime(3.0)
        lava.addChild(emitter)
    }

    // create grounds

    func createGrounds() {
        let botGround = SKSpriteNode(imageNamed: "Ground")
        botGround.position = CGPoint(x: size.width, y: bottomLimit + botGround.frame.height / 2 - 20)
        botGround.physicsBody = SKPhysicsBody(rectangleOf: botGround.size)
        botGround.physicsBody?.categoryBitMask = PhysicsCatagory.Ground
        botGround.physicsBody?.collisionBitMask = PhysicsCatagory.Explorer
        botGround.physicsBody?.contactTestBitMask = PhysicsCatagory.Explorer
        botGround.physicsBody?.affectedByGravity = false
        botGround.physicsBody?.isDynamic = false
        botGround.name = "ground"
        botGround.zPosition = 3
        addChild(botGround)

        let topGround = SKSpriteNode(imageNamed: "Ground")
        topGround.zRotation = CGFloat.pi
        topGround.position = CGPoint(x: size.width, y: topLimit - topGround.frame.height / 2 + 20)
        topGround.physicsBody = SKPhysicsBody(rectangleOf: botGround.size)
        topGround.physicsBody?.categoryBitMask = PhysicsCatagory.Ground
        topGround.physicsBody?.collisionBitMask = PhysicsCatagory.Explorer
        topGround.physicsBody?.contactTestBitMask = PhysicsCatagory.Explorer
        topGround.physicsBody?.affectedByGravity = false
        topGround.physicsBody?.isDynamic = false
        topGround.name = "ground"
        topGround.zPosition = 3
        addChild(topGround)

        let distance = CGFloat(frame.width)
        let moveGround = SKAction.moveBy(x: -2 * distance, y: 0, duration: 2 * groundMoveTime)
        let removeGround = SKAction.removeFromParent()
        let moveAndRemove = SKAction.sequence([moveGround, removeGround])

        botGround.run(moveAndRemove)
        topGround.run(moveAndRemove)
    }

    // createWalls

    func createWalls() {
        let wallPair = SKNode()
        wallPair.name = "wallPair"

        let topWall = SKSpriteNode(imageNamed: "wall")
        let btmWall = SKSpriteNode(imageNamed: "wall")

        topWall.position = CGPoint(x: frame.width / 2 + 25, y: topWall.size.height / 2 + random(min: 100, max: 150))
        btmWall.position = CGPoint(x: frame.width / 2 + 25, y: -(btmWall.size.height / 2 + random(min: 100, max: 150)))

        topWall.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: topWall.size.width * 0.5, height: topWall.size.height))
        topWall.physicsBody?.categoryBitMask = PhysicsCatagory.Wall
        topWall.physicsBody?.collisionBitMask = PhysicsCatagory.Explorer
        topWall.physicsBody?.contactTestBitMask = PhysicsCatagory.Explorer
        topWall.physicsBody?.isDynamic = false
        topWall.physicsBody?.affectedByGravity = false

        btmWall.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: btmWall.size.width * 0.5, height: btmWall.size.height))
        btmWall.physicsBody?.categoryBitMask = PhysicsCatagory.Wall
        btmWall.physicsBody?.collisionBitMask = PhysicsCatagory.Explorer
        btmWall.physicsBody?.contactTestBitMask = PhysicsCatagory.Explorer
        btmWall.physicsBody?.isDynamic = false
        btmWall.physicsBody?.affectedByGravity = false

        btmWall.zRotation = CGFloat(Double.pi)

        wallPair.addChild(topWall)
        wallPair.addChild(btmWall)

        wallPair.zPosition = 1

        let randomPosition = random(min: -random(min: 200, max: 250), max: random(min: 200, max: 250))
        wallPair.position.y = wallPair.position.y + randomPosition

        addChild(wallPair)

        let distance = CGFloat(frame.width)
        let moveWall = SKAction.moveBy(x: -distance - 50, y: 0, duration: moveTime)
        let removeWall = SKAction.removeFromParent()
        let moveAndRemove = SKAction.sequence([moveWall, removeWall])

        wallPair.run(moveAndRemove)
    }
}

// MARK: - update related

extension GameScene {
    func updateStage() {
        if stage1 {
            stage1 = false
            let delayGround = SKAction.wait(forDuration: groundMoveTime)
            let SpawnGround = SKAction.sequence([
                SKAction.run { self.createGrounds() }, delayGround])
            run(SKAction.repeatForever(SpawnGround))

            let delayWalls = SKAction.wait(forDuration: moveTime / 3)
            let SpawnWalls = SKAction.sequence([
                SKAction.run { self.createWalls() }, delayWalls])
            run(SKAction.repeatForever(SpawnWalls))
        }
    }
}

// MARK: - helper

extension GameScene {
    func sceneCropAmount() -> CGFloat {
        guard let view = view else { return 0 }

        let scale = view.bounds.size.width / size.width
        print("scale: \(scale)")
        let scaledHeight = size.height * scale
        let scaledOverlap = scaledHeight - view.bounds.size.height
        return scaledOverlap / scale
    }

    func createBTN() {
        restartBTN = SKSpriteNode(imageNamed: "RestartBtn")
        restartBTN.position = CGPoint(x: 0, y: 0)
        restartBTN.zPosition = 6
        restartBTN.setScale(0)
        addChild(restartBTN)
        restartBTN.run(SKAction.scale(to: 1.0, duration: 0.3))
    }
}

// MARK: - functions

extension GameScene: SKPhysicsContactDelegate {
    // MARK: - restartScene

    func restartScene() {
        let newScene = GameScene(fileNamed: "GameScene")
        newScene!.scaleMode = .aspectFill
        let reveal = SKTransition.flipVertical(withDuration: 0.5)
        view?.presentScene(newScene!, transition: reveal)
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let firstBody = contact.bodyA
        let secondBody = contact.bodyB

        if firstBody.categoryBitMask == PhysicsCatagory.Explorer && secondBody.categoryBitMask == PhysicsCatagory.Wall || firstBody.categoryBitMask == PhysicsCatagory.Wall && secondBody.categoryBitMask == PhysicsCatagory.Explorer {
            explorer.run(SKAction.move(by: CGVector(dx: -40, dy: 0), duration: 0.1))
        } else if firstBody.categoryBitMask == PhysicsCatagory.Explorer && secondBody.categoryBitMask == PhysicsCatagory.Ground || firstBody.categoryBitMask == PhysicsCatagory.Ground && secondBody.categoryBitMask == PhysicsCatagory.Explorer {
            explorer.run(SKAction.move(by: CGVector(dx: -40, dy: 0), duration: 0.1))
        }
    }
}

// MARK: - GADFullScreenContentDelegate

extension GameScene: GADFullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("adDidDismissFullScreenContent")
        restartScene()
    }
}

// MARK: - Notifications

extension GameScene {
    func addObservers() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] _ in
            self?.applicationDidBecomeActive()
        }
        notificationCenter.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: nil) { [weak self] _ in
            self?.applicationWillResignActive()
        }
        notificationCenter.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
            self?.applicationDidEnterBackground()
        }
    }

    func applicationDidBecomeActive() {
        print("* applicationDidBecomeActive")
        gameState = .play
        lastUpdateTimeInterval = 0
        isPaused = false
    }

    func applicationWillResignActive() {
        print("* applicationWillResignActive")
        gameState = .pause
        isPaused = true
    }

    func applicationDidEnterBackground() {
        print("* applicationDidEnterBackground")
        gameState = .pause
        isPaused = true
    }
}
