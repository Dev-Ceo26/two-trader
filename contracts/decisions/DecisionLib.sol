// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title DecisionLib
/// @notice Canone delle decisioni che attraversano il bridge Imperium.
///         Nessun campo opaco. Nessun bytes. Solo campi nominati.
///         Ogni decisione che conta deve essere esprimibile con questa struct.
library DecisionLib {
    /// @notice Tipi di decisione ammessi. Ogni nuovo tipo va aggiunto qui
    ///         e documentato in docs/CANON.md prima di essere usato.
    uint8 internal constant KIND_DEPOSIT          = 1;
    uint8 internal constant KIND_WITHDRAW         = 2;
    uint8 internal constant KIND_REGISTER_TOKEN   = 3;
    uint8 internal constant KIND_EMERGENCY        = 4;

    /// @notice Struttura canonica di una decisione.
    /// @param  kind           Tipo di decisione (vedi costanti sopra)
    /// @param  actor          Chi ha originato la decisione (msg.sender on-chain)
    /// @param  token          Token coinvolto (address(0) se non applicabile)
    /// @param  recipient      Destinatario (address(0) se non applicabile)
    /// @param  amount         Importo (0 se non applicabile)
    /// @param  nonce          Anti-replay, unico per (actor, kind)
    /// @param  srcChainId     Catena di origine
    /// @param  dstChainId     Catena di destinazione
    /// @param  deadline       Dopo questo timestamp la firma e' invalida (0 = nessuna scadenza)
    /// @param  rationaleHash  keccak256 di una spiegazione umana off-chain (IPFS, URL, README)
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
            d.rationaleHash
        ));
    }

    /// @notice Verifica che una decisione sia ben formata per il suo kind.
    /// @dev    Regola del canone: se non passa qui, non puo' essere registrata.
    function validate(Decision memory d) internal pure returns (bool) {
        if (d.actor == address(0)) return false;
        if (d.srcChainId == 0) return false;
        if (d.dstChainId == 0) return false;

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
}
