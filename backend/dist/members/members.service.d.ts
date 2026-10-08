import { PrismaService } from '../prisma/prisma.service';
export declare class MembersService {
    private p;
    constructor(p: PrismaService);
    all(a: bigint): Promise<{
        id: number;
        name: any;
        email: any;
        phone: any;
        gender: any;
        age: any;
        plan: any;
        duration_months: any;
        fee: number;
        joining_date: string | null;
        expiry_date: string | null;
        status: any;
        notes: any;
        keycard: any;
        pr_kg: number;
        photo: any;
        created_at: string | null;
    }[]>;
    one(a: bigint, id: string): Promise<{
        id: number;
        name: any;
        email: any;
        phone: any;
        gender: any;
        age: any;
        plan: any;
        duration_months: any;
        fee: number;
        joining_date: string | null;
        expiry_date: string | null;
        status: any;
        notes: any;
        keycard: any;
        pr_kg: number;
        photo: any;
        created_at: string | null;
    }>;
    key(a: bigint, c?: string, e?: string): Promise<{
        taken: boolean;
    }>;
    body(a: bigint, b: any): {
        adminId: bigint;
        name: any;
        email: any;
        phone: any;
        gender: any;
        age: number;
        plan: any;
        durationMonths: number;
        fee: any;
        joiningDate: Date;
        expiryDate: Date;
        status: any;
        notesText: any;
        keycard: any;
        prKg: any;
        createdAt: Date;
    };
    add(a: bigint, b: any): Promise<{
        id: number;
    }>;
    update(a: bigint, id: string, b: any): Promise<{
        success: boolean;
    }>;
    renew(a: bigint, id: string, b: any): Promise<{
        success: boolean;
    }>;
    adjustment(a: bigint, id: string, b: any): Promise<{
        success: boolean;
    }>;
    status(a: bigint, id: string, x: boolean): Promise<{
        success: boolean;
    }>;
    pr(a: bigint, id: string, kg: any): Promise<{
        success: boolean;
    }>;
    photo(a: bigint, id: string, f?: Express.Multer.File): Promise<{
        success: boolean;
    }>;
    del(a: bigint, id: string): Promise<{
        deleted: number;
    }>;
    clean(a: bigint): Promise<{
        deleted: number;
    }>;
    notes(a: bigint, id: string): Promise<{
        id: number;
        member_id: number;
        title: string;
        body: string;
        tags: string;
        created_at: string;
    }[]>;
    addNote(a: bigint, id: string, b: any): Promise<{
        success: boolean;
    }>;
}
