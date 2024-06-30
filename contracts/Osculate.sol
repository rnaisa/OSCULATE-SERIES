// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.12 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "hardhat/console.sol";

 /**
  *                        .-\\\\\\\-.          .-\\\\\\\-.                                
  *                     .\\\\\\\\\\\\\\\\-.  .\\\\\\\\\\\\\\\\\.                           
  *                    .\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\.                  
  *       _____   ____    ____     __  __  __       ______  ______  ____    ____      
  *      /\  __`\/\  _`\ /\  _`\  /\ \/\ \/\ \     /\  _  \/\__  _\/\  _`\ /\  _`\    
  *      \ \ \/\ \ \,\L\_\ \ \/\_\\ \ \ \ \ \ \    \ \ \L\ \/_/\ \/\ \ \L\_\ \ \/\ \  
  *       \ \ \ \ \/_\__ \\ \ \/_/_\ \ \ \ \ \ \  __\ \  __ \ \ \ \ \ \  _\L\ \ \ \ \ 
  *        \ \ \_\ \/\ \L\ \ \ \L\ \\ \ \_\ \ \ \L\ \\ \ \/\ \ \ \ \ \ \ \L\ \ \ \_\ \
  *         \ \_____\ `\____\ \____/ \ \_____\ \____/ \ \_\ \_\ \ \_\ \ \____/\ \____/
  *          \/_____/\/_____/\/___/   \/_____/\/___/   \/_/\/_/  \/_/  \/___/  \/___/         
  *
  *                                        .-\\\\\\\\\\\\\\\\\-.                            
  *                                            .-\\\\\\\\\\-.                               
  *                                                  .\\\\\.
  *                                                      \.
  */

/**
 * @title Osculate
 * @author rnaisa
 * @notice A contract where each newly minted NFT kisses the previous one by vigenere ciphering part of their owners' addresses.
 * @dev The vigenere ciphered text appears on the token's image and doesn't change when tokens are transferred.
 * The last minted token of the contract remains unkissed until a new one is minted.
 */
contract Osculate is ERC721, Ownable {
    uint256 private _totalSupply;
    // Mapping of tokenId to ciphered text in bytes (that's shown on the nft's image as strings)
    mapping(uint256 => bytes) private tokenToCipher;
    // Alphabet used for the vigenere cipher
    bytes private constant ALPH = "abcdefghijklmnopqrstuvwxyz0123456789";
    uint256 private constant ALPHABET_LENGTH = 36;

    /**
     * @dev Constructor that mints the first NFT with the word "osculate" as the ciphered text.
     */
    constructor() ERC721("OSCULATE", "OSC") Ownable(msg.sender) {
        _safeMint(msg.sender, _totalSupply);
        require(
            ownerOf(_totalSupply) == owner(),
            "Owner of first minted NFT is not the contract owner"
        );
        // Set starting word
        tokenToCipher[_totalSupply] = "osculate";
        _totalSupply++;
    }

    /**
     * @notice Mints next NFT to the sender's address for 1 gwei
     * @dev The previous token's cipher is vigenere ciphered
     * with the last eight lowercase characters of the sender's address.
     * The ciphered text of type bytes is saved to the tokenToCipher mapping and the total supply updated.
     * The sender can't mint a new token if they own the last minted token.
     */
    function mint() public payable {
        require(msg.value >= 1 gwei, "Insufficient funds to mint");
        _safeMint(msg.sender, _totalSupply);
        require(
            ownerOf(_totalSupply) != address(0),
            "Minted token's owner can't be the null address"
        );
        require(
            ownerOf(_totalSupply) == msg.sender,
            "Owner of minted token is not the sender"
        );
        require(
            ownerOf(_totalSupply - 1) != msg.sender,
            "You can't kiss yourself!"
        );
        tokenToCipher[_totalSupply] = vigenereCipherToBytes(
            tokenToCipher[_totalSupply - 1],
            extractlastEightCharsToBytes(msg.sender)
        );
        _totalSupply++;
    }

    /**
     * @notice Returns the total supply of NFTs minted.
     */
    function getSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @notice Returns the live metadata of the NFT with the given tokenId.
     * @dev The output of getMetadata() generates tokenId-dependent values
     * and updates when the token has been kissed.
     * @param tokenId The tokenId of the NFT requested.
     * @return The metadata as a data URI with the SVG image and attributes.
     */
    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        require(tokenId < _totalSupply, "Invalid tokenId");
        bytes memory json = abi.encodePacked(
            '{"name":"OSCULATED NR.',
            " ",
            Strings.toString(tokenId),
            '",',
            '"description":"OSCULATE SERIES: A sequence of kissed tokens. rnaisa, 2024.',
            '",',
            '"image":"',
            "data:image/svg+xml,",
            getMetadata(tokenId)
        );

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(json)
                )
            );
    }

    // ======== VIGENERE CIPHER FUNCTIONS ========

    /**
     * @dev Vigenere cipher function that takes two bytes arrays of length 8
     * and returns a bytes array of length 8.
     * @param inputBytes The plaintext as bytes to be ciphered.
     * @param keyBytes The key as bytes to cipher the plaintext.
     */
    function vigenereCipherToBytes(
        bytes memory inputBytes,
        bytes memory keyBytes
    ) private pure returns (bytes memory) {
        require(
            inputBytes.length == 8 && keyBytes.length == 8,
            "Vigenere Cipher input and or key bytes are not of length 8"
        );
        bytes memory output = new bytes(inputBytes.length);

        for (uint256 i = 0; i < inputBytes.length; i++) {
            uint8 inputIndex = getAlphabetIndex(inputBytes[i]);
            uint8 keyIndex = getAlphabetIndex(keyBytes[i % keyBytes.length]);
            uint8 cipherIndex = uint8(
                (inputIndex + keyIndex) % uint8(ALPHABET_LENGTH)
            );
            output[i] = ALPH[cipherIndex];
        }

        require(output.length == 8, "Result bytes cipher is not of length 8");
        return output;
    }

    /**
     * @dev Returns the index of the character in the alphabet.
     * @param char The character to find.
     */
    function getAlphabetIndex(bytes1 char) internal pure returns (uint8) {
        for (uint8 i = 0; i < ALPH.length; i++) {
            if (ALPH[i] == char) {
                return i;
            }
        }
        revert("Character not in alphabet");
    }

    /**
     * @param addr The address to extract the last eight characters from.
     */
    function extractlastEightCharsToBytes(
        address addr
    ) private pure returns (bytes memory) {
        bytes memory buff = bytes(Strings.toHexString(addr));
        bytes memory b;

        assembly {
            // make b point to the free memory pointer
            b := mload(0x40)

            // add the length of bytes array as the first 32 bytes
            mstore(b, 8)

            // add the last 8 bytes (the last 8 characters of the address) to b
            mstore(add(b, 0x20), mload(add(buff, 0x42)))

            // update the free memory pointer so solidity can use it
            mstore(0x40, add(b, 0x40))
        }
        require(
            b.length == 8,
            "Extracted bytes for vigenere cipher is not of length 8"
        );
        return b;
    }

    /**
     * @dev If the tokenId is 0, the function returns the cipher of the first token.
     * Otherwise, it returns the cipher of the token that was minted before tokenId.
     */
    function getCipherOfPrevToken(
        uint256 tokenId
    ) private view returns (string memory) {
        require(tokenId < _totalSupply, "Invalid tokenId");
        uint256 prevToken = tokenId != 0 ? tokenId - 1 : 0;
        return
            string(tokenToCipher[prevToken = tokenId != 0 ? tokenId - 1 : 0]);
    }

    // ======== SVG FUNCTIONS ========

    /**
     * @dev Uses the tokenId to generate token-specific settings for the SVG image.
     * This includes the pattern's ciphered text, the seed, the color, and the scale of the background pattern.
     * Each newly minted token's image has a normal heartbeat animation and the color's saturation value
     * set to 0 (black & white) that changes if the token has been kissed.
     * If kissed, the SVG image will have a faster heartbeat animation and the color appears.
     */
    function getMetadata(uint256 tokenId) private view returns (bytes memory) {
        // Checks if the requested token has been kissed (e.g a token has been minted after it)
        bool kissedVal = (_totalSupply - 1) > tokenId;
        // Get the array with the rotated ciphers to use for the SVG texts
        string[9] memory cipheredPattern = generateCipherPatternArray(
            tokenToCipher[tokenId]
        );
        require(
            bytes(cipheredPattern[0]).length == 8,
            "First cipher pattern is not 8 characters long"
        );

        bytes memory SVGHeader = abi.encodePacked(
            "<svg width='450' height='450' xmlns='http://www.w3.org/2000/svg'>",
            "<defs>",
            "<filter id='displacementCircle'>",
            "<feTurbulence type='turbulence' baseFrequency='0.06' numOctaves='4' result='turbulence' seed='",
            Strings.toString(tokenId), // Set seed per token
            "'/>",
            "<feDisplacementMap in2='turbulence' in='SourceGraphic' scale='700' xChannelSelector='R' yChannelSelector='B'/>",
            "</filter>",
            "<circle id='circleEl' cx='-150' cy='-150' r='350' fill='hsl(0,0%25,70%25,0.8)' filter='url(%23displacementCircle)' transform='rotate(180)'>",
            "<animate attributeName='fill' values='white;grey;white;grey;' dur='",
            getAnimationDuration(kissedVal), // Heartbeat animation duration
            "' repeatCount='indefinite'/>",
            "</circle>",
            getFiltersAndGroupStart()
        );

        // Get the SVG text elements with the ciphered text pattern
        bytes memory SVGText = generateTextSVG(cipheredPattern);

        // Get the scale values for the background pattern's definition
        (string memory scaleOne, string memory scaleTwo) = getScale(tokenId);
        bytes memory SVGFooter = abi.encodePacked(
            "</g>",
            "</defs>",
            "<rect width='100%25' height='100%25' fill='hsl(0, 0%25, 5%25, 1)'/>",
            "<circle cx='500' cy='250' r='500' fill='none' stroke='hsl(",
            addressToColor(tokenId), // Calculate owner address deterministic color between 0 and 360
            ",",
            getStrokeSaturation(kissedVal), // Color display based on kissed value
            "%25,20%25,1)' stroke-width='50' filter='url(%23displacementCircle)' transform='scale(",
            scaleOne, // Scale Digits
            ".",
            scaleTwo,
            ")'/>",
            "<use href='%23textGroup' fill='hsl(0,0%25,100%25, 1)' filter='url(%23compIn)' style='font:27px Courier New;'/>",
            "<use href='%23textGroup' fill='hsl(0,0%25,50%25, 0.6)' style='font:27px Courier New;'/>",
            '</svg>",'
        );

        // Token's attributes include the previous token's cipher and if the token has been kissed.
        bytes memory Attributes = abi.encodePacked(
            ' "attributes": [',
            '{"trait_type": "Previous Token Ciphertext", "value": "',
            getCipherOfPrevToken(tokenId),
            '"},',
            '{"trait_type": "Kissed", "value": ',
            kissedVal ? '"yes"' : '"no"',
            "}]}"
        );

        return abi.encodePacked(SVGHeader, SVGText, SVGFooter, Attributes);
    }

    /**
     * @dev Generates the vigenere cipher table inspired SVG text elements with the ciphered text pattern.
     */
    function generateTextSVG(
        string[9] memory cipheredPattern
    ) private pure returns (bytes memory) {
        return
            abi.encodePacked(
                "<text x='50%25' y='25' textLength='93%25' lengthAdjust='spacing' text-anchor='middle'>_",
                cipheredPattern[0],
                "</text>",
                "<text x='50%25' y='75' textLength='93%25' lengthAdjust='spacing' text-anchor='middle'>",
                cipheredPattern[1],
                "</text>",
                "<text x='50%25' y='125' textLength='93%25' lengthAdjust='spacing' text-anchor='middle'>",
                cipheredPattern[2],
                "</text>",
                "<text x='50%25' y='175' textLength='93%25' lengthAdjust='spacing' text-anchor='middle'>",
                cipheredPattern[3],
                "</text>",
                "<text x='50%25' y='225' textLength='93%25' lengthAdjust='spacing' text-anchor='middle'>",
                cipheredPattern[4],
                "</text>",
                "<text x='50%25' y='275' textLength='93%25' lengthAdjust='spacing' text-anchor='middle'>",
                cipheredPattern[5],
                "</text>",
                "<text x='50%25' y='325' textLength='93%25' lengthAdjust='spacing' text-anchor='middle'>",
                cipheredPattern[6],
                "</text>",
                "<text x='50%25' y='375' textLength='93%25' lengthAdjust='spacing' text-anchor='middle'>",
                cipheredPattern[7],
                "</text>",
                "<text x='50%25' y='425' textLength='93%25' lengthAdjust='spacing' text-anchor='middle'>",
                cipheredPattern[8],
                "</text>"
            );
    }

    /**
     * @dev Creates the array of strings to be used for the SVG text element contents.
     * The first entry is the normal cipher, the following entries are rotated ciphers
     * with the first character repeating twice at the beginning.
     * @param strBytes The ciphered text as bytes to generate the pattern from.
     */
    function generateCipherPatternArray(
        bytes memory strBytes
    ) private pure returns (string[9] memory) {
        string[9] memory result;

        // First string is the normal cipher
        result[0] = string(strBytes);

        // Rotates the cipher for the pattern (f.e oosculate, ssculateo, ...)
        for (uint256 i = 0; i < 8; i++) {
            bytes memory line = new bytes(9);
            line[0] = strBytes[i]; // add the starting character

            for (uint256 j = 0; j < 8; j++) {
                line[j + 1] = strBytes[(i + j) % 8];
            }

            result[i + 1] = string(line);
        }

        return result;
    }

    // ======== SVG HELPER FUNCTIONS ========

    /**
     * @dev If the token has been kissed, the animation changes from normal (1.5s), to fast (0.7s).
     */
    function getAnimationDuration(
        bool kissedVal
    ) private pure returns (string memory) {
        return kissedVal ? "0.7" : "1.5";
    }

    /**
     * @dev Returns the saturation value for the HSL stroke color of the token's image.
     * Saturation stays at 0% if the token has not been kissed (black & white),
     * otherwise it's 30%.
     * @param kissedVal If the token has been kissed.
     */
    function getStrokeSaturation(
        bool kissedVal
    ) private pure returns (string memory) {
        return kissedVal ? "30" : "0";
    }

    /**
     * @return The SVG filters and group start for the token's image.
     */
    function getFiltersAndGroupStart() private pure returns (bytes memory) {
        return
            abi.encodePacked(
                "<filter id='compIn'><feImage href='%23circleEl' result='img'/><feComposite in='img' in2='SourceGraphic' operator='in'/></filter><g id='textGroup' dominant-baseline='central'><rect x='0' y='50' width='100%25' height='1'/><rect x='50' y='0' width='1' height='100%25'/>"
            );
    }

    /**
     *   @dev The SVG scale value used for the background pattern ranges from 1.5 to 6.0.
     *   Lower tokenId numbers have bigger scale (less defined patterns),
     *   higher ones have lower scales (more defined patterns).
     *   Essentially, the scale is calculated as 6 - (tokenId * 0.1) and stops at 1.5 (tokenId > 45).
     *   @return Values between 15 to 60, split into two separate strings
     *   that can be used to simulate float number digits in the SVG.
     **/
    function getScale(
        uint256 tokenId
    ) private pure returns (string memory, string memory) {
        uint256 scale = 10; // Use a scale of 10 to handle one decimal place (e.g., 1.5 -> 15)

        uint256 scaledValue = (6 * scale) - ((tokenId * scale) / 10);

        // once the scale reaches 1.5, it stays at that value
        uint256 result = scaledValue < (15) ? 15 : scaledValue;

        bytes memory bytesResultOne = new bytes(1);
        bytes memory bytesResultTwo = new bytes(1);
        bytesResultOne[0] = bytes(Strings.toString(result))[0];
        bytesResultTwo[0] = bytes(Strings.toString(result))[1];

        return (string(bytesResultOne), string(bytesResultTwo));
    }

    /**
     * @dev Uses the the owner's address' hash to help determine the color
     * of the token's image background pattern.
     * @return A color value between 0 and 360 based on the owner's address.
     */
    function addressToColor(
        uint256 tokenId
    ) private view returns (string memory) {
        return
            Strings.toString(
                uint256(uint16(bytes2(hashAddrOfTokenOwner(tokenId)))) % 361
            );
    }

    /**
     * @dev Hash used to help generate a deterministic color from the owner's address.
     */
    function hashAddrOfTokenOwner(
        uint256 tokenId
    ) private view returns (bytes32) {
        return keccak256(abi.encodePacked(ownerOf(tokenId)));
    }
}
