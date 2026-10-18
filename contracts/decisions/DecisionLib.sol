// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title DecisionLib
/// @notice Canone delle decisioni che attraversano il bridge T2T.
///         Versione 1.2 — aggiunge fee e feeRecipient per il supporto
///         a depositi diretti (fee=0) e cross-chain (fee>0).
///         Nessun campo opaco. Nessun bytes. Solo campi nominati.
library DecisionLib {
    /// @notice Tipi di decisione ammessi.
    uint8 internal constant KIND_DEPOSIT        = 1;
    uint8 internal constant KIND_WITHDRAW       = 2;
    uint8 internal constant KIND_REGISTER_TOKEN = 3;
    uint8 internal constant KIND_EMERGENCY      = 4;

    /// @notice Tetto massimo alla fee, in basis points (1% = 100 bps).
    ///         Hard-coded, immutabile. Nessuna fee puo' superare questo valore,
    ///         nemmeno se il governor lo richiede.
    uint256 internal constant MAX_FEE_BPS = 100;

    /// @notice Struttura canonica di una decisione.
    /// @dev    L'ordine dei campi e' parte del canone. Aggiungere solo in coda.
    struct Decision {
        uint8   kind;
        address actor;
        address token;
        address recipient;
        uint256 amount;
        uint256 nonce;
        uint256 srcChainId;
        uint256 dstChainId;
        uint64  deadline;
        bytes32 rationaleHash;
        // --- v1.2 ---
        uint256 fee;             // 0 se deposito diretto, >0 se cross-chain
        address feeRecipient;    // 0x0 se fee == 0
    }

    /// @notice Hash canonico della decisione. Usato per firme e per ID.
    /// @dev    L'ordine dei campi e' parte del canone: non cambiarlo mai
    ///         senza bumpare una versione esplicita.
    function hash(Decision memory d) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            d.kind,
            d.actor,
            d.token,
            d.recipient,
            d.amount,
            d.nonce,
            d.srcChainId,
            d.dstChainId,
            d.deadline,
            d.rationaleHash,
            d.fee,
            d.feeRecipient
        ));
    }

    /// @notice Verifica che una decisione sia ben formata per il suo kind.
    /// @dev    Regola del canone: se non passa qui, non puo' essere registrata.
    function validate(Decision memory d) internal pure returns (bool) {
        if (d.actor == address(0)) return false;
        if (d.srcChainId == 0) return false;
        if (d.dstChainId == 0) return false;
        if (d.deadline == 0) return false;

        // Regole fee: deposito diretto (stessa chain) = fee zero.
        if (d.srcChainId == d.dstChainId) {
            if (d.fee != 0) return false;
            if (d.feeRecipient != address(0)) return false;
        } else {
            // Cross-chain: se c'e' fee, deve esserci un recipient.
            if (d.fee > 0 && d.feeRecipient == address(0)) return false;
            if (d.fee == 0 && d.feeRecipient != address(0)) return false;
            // Tetto massimo alla fee (1% del lordo).
            if (d.amount > 0) {
                uint256 maxFee = (d.amount * MAX_FEE_BPS) / 10000;
                if (d.fee > maxFee) return false;
            } else {
                if (d.fee > 0) return false;
            }
        }

        if (d.kind == KIND_DEPOSIT || d.kind == KIND_WITHDRAW) {
            if (d.token == address(0)) return false;
            if (d.recipient == address(0)) return false;
            if (d.amount == 0) return false;
            return true;
        }

        if (d.kind == KIND_REGISTER_TOKEN) {
            if (d.token == address(0)) return false;
            return true;
        }

        if (d.kind == KIND_EMERGENCY) {
            return true;
        }

        return false;
    }

    /// @notice Deadline superata?
    function isExpired(Decision memory d, uint256 nowTs) internal pure returns (bool) {
        if (d.deadline == 0) return false;
        return nowTs > d.deadline;
    }

    /// @notice Calcola la fee in basis points sull'importo lordo.
    /// @dev    Non verifica il tetto: la verifica e' in `validate`.
    function computeFee(uint256 amount, uint256 feeBps) internal pure returns (uint256) {
        return (amount * feeBps) / 10000;
    }
}
