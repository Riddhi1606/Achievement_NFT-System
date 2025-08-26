;; Achievement NFT System Contract
;; Universal gaming achievement system that works across multiple games and platforms

;; Define the NFT
(define-non-fungible-token achievement-nft uint)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-achievement-not-found (err u102))
(define-constant err-already-awarded (err u103))
(define-constant err-invalid-game (err u104))

;; Data variables
(define-data-var last-achievement-id uint u0)
(define-data-var contract-uri (optional (string-utf8 256)) none)

;; Achievement metadata structure
(define-map achievement-metadata uint {
    name: (string-utf8 64),
    description: (string-utf8 256),
    game-platform: (string-utf8 64),
    difficulty: (string-utf8 16),
    points: uint,
    image-uri: (optional (string-utf8 256))
})

;; Track which players have earned which achievements
(define-map player-achievements {player: principal, achievement-id: uint} bool)

;; Authorized game platforms (only these can mint achievements)
(define-map authorized-games principal bool)

;; Function 1: Mint Achievement NFT
;; Allows authorized game platforms to mint achievement NFTs for players
(define-public (mint-achievement 
    (recipient principal)
    (name (string-utf8 64))
    (description (string-utf8 256))
    (game-platform (string-utf8 64))
    (difficulty (string-utf8 16))
    (points uint)
    (image-uri (optional (string-utf8 256))))
  (let ((achievement-id (+ (var-get last-achievement-id) u1)))
    (begin
      ;; Check if caller is authorized (owner or authorized game)
      (asserts! (or (is-eq tx-sender contract-owner) 
                    (default-to false (map-get? authorized-games tx-sender))) 
                err-not-authorized)
      
      ;; Check if player already has this specific achievement
      (asserts! (is-none (map-get? player-achievements {player: recipient, achievement-id: achievement-id})) 
                err-already-awarded)
      
      ;; Mint the NFT
      (try! (nft-mint? achievement-nft achievement-id recipient))
      
      ;; Store achievement metadata
      (map-set achievement-metadata achievement-id {
        name: name,
        description: description,
        game-platform: game-platform,
        difficulty: difficulty,
        points: points,
        image-uri: image-uri
      })
      
      ;; Mark achievement as earned by player
      (map-set player-achievements {player: recipient, achievement-id: achievement-id} true)
      
      ;; Update last achievement ID
      (var-set last-achievement-id achievement-id)
      
      ;; Return achievement ID
      (ok achievement-id))))

;; Function 2: Get Player Achievement Details
;; Retrieves comprehensive achievement information for a specific player and achievement
(define-read-only (get-player-achievement-details (player principal) (achievement-id uint))
  (let ((has-achievement (default-to false (map-get? player-achievements {player: player, achievement-id: achievement-id})))
        (metadata (map-get? achievement-metadata achievement-id))
        (nft-owner (nft-get-owner? achievement-nft achievement-id)))
    (if has-achievement
      (ok {
        player: player,
        achievement-id: achievement-id,
        owned: (is-some nft-owner),
        current-owner: nft-owner,
        metadata: metadata,
        earned: true
      })
      (ok {
        player: player,
        achievement-id: achievement-id,
        owned: false,
        current-owner: none,
        metadata: metadata,
        earned: false
      }))))

;; Helper functions for contract management

;; Authorize a game platform to mint achievements
(define-public (authorize-game (game-contract principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set authorized-games game-contract true)
    (ok true)))

;; Get achievement metadata
(define-read-only (get-achievement-metadata (achievement-id uint))
  (ok (map-get? achievement-metadata achievement-id)))

;; Get total achievements minted
(define-read-only (get-total-achievements)
  (ok (var-get last-achievement-id)))

;; SIP-009 NFT trait compliance
(define-read-only (get-last-token-id)
  (ok (var-get last-achievement-id)))

(define-read-only (get-token-uri (token-id uint))
  (ok (var-get contract-uri)))

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? achievement-nft token-id)))