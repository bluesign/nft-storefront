/// This script uses the NFTMinter resource to mint a new NFT
/// It must be run with the account that has the minter resource
/// stored in /storage/NFTMinter

import NonFungibleToken from "NonFungibleToken"
import ExampleNFT from "ExampleNFT"
import MetadataViews from "MetadataViews"
import FungibleToken from "FungibleToken"

// TODO: Replace with transaction params once CLI bug is fixed
// transaction(
//     recipient: Address,
//     name: String,
//     description: String,
//     thumbnail: String,
//     cuts: [UFix64],
//     royaltyDescriptions: [String],
//     royaltyBeneficiaries: [Address]
// ) {
transaction {

    // TODO: Replace with transaction params once CLI bug is fixed
    let recipient: Address
    let name: String
    let description: String
    let thumbnail: String
    let cuts: [UFix64]
    let royaltyDescriptions: [String]
    let royaltyBeneficiaries: [Address]

    /// local variable for storing the minter reference
    let minter: &ExampleNFT.NFTMinter

    /// Reference to the receiver's collection
    let recipientCollectionRef: &{NonFungibleToken.Collection}

    prepare(signer: auth(BorrowValue) &Account) {
        // TODO: Replace with transaction params once CLI bug is fixed
        self.recipient = 0x01cf0e2f2f715450
        self.name = "test"
        self.description = "testing"
        self.thumbnail = "flow.com/logo.jpg"
        self.cuts = []
        self.royaltyDescriptions = []
        self.royaltyBeneficiaries = []

        let collectionData = ExampleNFT.getCollectionData(nftType: Type<@ExampleNFT.NFT>())
            ?? panic("Missing collection data")

        // borrow a reference to the NFTMinter resource in storage
        self.minter = signer.storage.borrow<&ExampleNFT.NFTMinter>(from: ExampleNFT.MinterStoragePath)
            ?? panic("Account does not store an object at the specified path")

        // Borrow the recipient's public NFT collection reference
        self.recipientCollectionRef = getAccount(self.recipient).capabilities.borrow<&{NonFungibleToken.Collection}>(
                collectionData.publicPath
            ) ?? panic("Could not get receiver reference to the NFT Collection")
    }

    pre {
        self.cuts.length == self.royaltyDescriptions.length &&
        self.cuts.length == self.royaltyBeneficiaries.length:
            "Array length should be equal for royalty related details"
    }

    execute {

        // Create the royalty details
        var count = 0
        var royalties: [MetadataViews.Royalty] = []
        while self.royaltyBeneficiaries.length > count {
            let beneficiary = self.royaltyBeneficiaries[count]
            let beneficiaryCapability = getAccount(beneficiary).capabilities.get<&{FungibleToken.Receiver}>(
                    MetadataViews.getRoyaltyReceiverPublicPath()
                ) ?? panic("No beneficiary capability found")

            // Make sure the royalty capability is valid before minting the NFT
            if !beneficiaryCapability.check() { panic("Beneficiary capability is not valid!") }

            royalties.append(
                MetadataViews.Royalty(
                    receiver: beneficiaryCapability,
                    cut: self.cuts[count],
                    description: self.royaltyDescriptions[count]
                )
            )
            count = count + 1
        }

        // Mint the NFT and deposit it to the recipient's collection
        self.recipientCollectionRef.deposit(
            token: <-self.minter.mintNFT(
                name: self.name,
                description: self.description,
                thumbnail: self.thumbnail,
                royalties: royalties
            )
        )
    }
}