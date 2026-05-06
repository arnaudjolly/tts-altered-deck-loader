local cardBackURL = "https://steamusercontent-a.akamaihd.net/ugc/17955107422824437088/44C9BC47408AEFC8354A0261313BB8383B56B877/"
local url = ""

function onLoad()
    self.UI.setXml(ui)
end

ui = [[
<Panel id="loaderPanel" position="0 0 -35" width="700" height="230" color="#1e1e1eee">
    <VerticalLayout spacing="10" padding="10">

        <Text text="Altered Deck Loader" fontSize="30" alignment="MiddleCenter" />

        <InputField
            id="deckUrl"
            placeholder="Coller l'URL du deck ici"
            width="660"
            height="40"
            onEndEdit="storeUrl"
        />

        <Button
            text="Charger le deck"
            onClick="startLoad"
            width="300"
            height="50"
        />

    </VerticalLayout>
</Panel>
]]



function startLoad(player, value, id)


    if url == "" then
        broadcastToColor("Veuillez saisir une URL", player.color, {1,0,0})
        return
    end

    loadAlteredDeck(url, player)
end

function storeUrl(player, value, id)
    -- print(player.steam_name .. " entered: " .. value)

    -- store the value in a global variable for later access
    url = value
end

function loadAlteredDeck(url, player)
    if url then
        local deckId = url:match("decks/([%w]+)")
        if deckId then
            local apiUrl = "https://api.altered.gg/deck_user_lists/" .. deckId
            WebRequest.get(apiUrl, function(response)
                if response.is_error then
                    broadcastToAll("Erreur lors de la récupération du deck.", {1,0,0})
                    return
                end
                local deckData = JSON.decode(response.text)
                createDeckFromAltered(deckData, player)
            end)
        else
            broadcastToAll("Deck ID non trouvé dans l'URL.", {1,0,0})
        end
    else
        broadcastToAll("URL Altered.gg non reconnue.", {1,0,0})
    end
end


function createDeckFromAltered(deckData, player)
    local log = {}
    local cards = {}

    table.insert(log, "📦 Chargement du deck : " .. (deckData.name or "Sans nom"))

    -- Helper to add cards by type
    local function addCardsByType(typeName, logLabel)
        if deckData.deckCardsByType and deckData.deckCardsByType[typeName] and deckData.deckCardsByType[typeName].deckUserListCard then
            for _, card in ipairs(deckData.deckCardsByType[typeName].deckUserListCard) do
                local img = (card.card.allImagePath and card.card.allImagePath["en-us"]) or card.card.imagePath
                for i = 1, card.quantity do
                    table.insert(cards, {
                        face = img,
                        back = cardBackURL,
                        quantity = 1
                    })
                end
            end
            table.insert(log, "➕ " .. logLabel .. " ajoutés")
        end
    end

    addCardsByType("character", "Personnages")
    addCardsByType("spell", "Sorts")
    addCardsByType("permanent", "Permanents")
    
    -- Alterator (Héros) en dernier pour qu'il soit au dessus
    if deckData.alterator and deckData.alterator.imagePath then
        table.insert(cards, {
            face = deckData.alterator.imagePath,
            back = cardBackURL,
            quantity = 1
        })
        table.insert(log, "🧙 Alterator ajouté")
    else
        table.insert(log, "⚠️ Aucun alterator trouvé")
    end

    -- Construction du deck
    local customDeck = {}
    for i, card in ipairs(cards) do
        customDeck[i] = {
            face = card.face,
            back = card.back,
            width = 10,
            height = 7
        }
    end

    table.insert(log, "🎯 Total final : " .. #cards .. " cartes")
    -- Affichage des logs dans le chat
    for _, line in ipairs(log) do
        broadcastToColor(line, player.color, {1,1,1})
    end

    -- Création du deck sur la table
    spawnDeck(customDeck, #cards, deckData.name, player)
end

function spawnDeck(customDeck, cardCount, deckName, player)

    broadcastToColor("🛠 Création du deck en cours...", player.color, {0,1,1})
    local deckObj = {
        Name = "DeckCustom",
        Transform = {
            posX = 0,
            posY = 2,
            posZ = 0,
            rotX = 0,
            rotY = 180,
            rotZ = 0,
            scaleX = 1,
            scaleY = 1,
            scaleZ = 1
        },
        Nickname = deckName or "Altered Deck",
        Description = "",
        ColorDiffuse = {r=1,g=1,b=1},
        Locked = false,
        Grid = true,
        Snap = true,
        Autoraise = true,
        Sticky = true,
        Tooltip = true,
        CustomDeck = {},
        DeckIDs = {},
        -- Cards will be added below
    }

    for i, card in ipairs(customDeck) do
        deckObj.CustomDeck[tostring(i)] = {
            FaceURL = card.face,
            BackURL = card.back,
            NumWidth = 1,
            NumHeight = 1,
            BackIsHidden = true,
            UniqueBack = false
        }
        table.insert(deckObj.DeckIDs, i*100)
    end

    deckObj.Transform.posX, deckObj.Transform.posZ = getPlayerPosition(player)

    spawnObjectJSON({
        json = JSON.encode(deckObj),
        callback_function = function(obj)
            broadcastToColor("✅ Deck créé avec succès", player.color, {0,1,0})
        end
    })
end

function getPlayerPosition(player)
    -- Place le deck devant le joueur
    local p = Player[player.color]
    if p and p.getPointerPosition then
        local pos = p.getPointerPosition()
        return pos.x, pos.z
    end
    return 0, 0
end
