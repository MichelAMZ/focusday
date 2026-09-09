import { getAuth } from "firebase-admin/auth";

export interface VerifiedIdentity { uid: string; }
export interface FirebaseAuthVerifier {
  verifyIdToken(token: string): Promise<VerifiedIdentity>;
}

export class FirebaseAdminAuthVerifier implements FirebaseAuthVerifier {
  async verifyIdToken(token: string): Promise<VerifiedIdentity> {
    const decoded = await getAuth().verifyIdToken(token);
    return { uid: decoded.uid };
  }
}
