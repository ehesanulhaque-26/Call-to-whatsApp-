import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { HealthService } from './health.service';
import { SupabaseService } from '../supabase/supabase.service';
import { OpenWAService } from '../openwa/openwa.service';

describe('HealthService', () => {
  let service: HealthService;

  // Mock Supabase client - recreated for each test
  let mockSupabaseClient: any;
  let mockSupabaseService: any;
  let mockOpenWAService: any;
  let mockConfigService: any;

  beforeEach(async () => {
    // Create fresh mocks for each test
    mockSupabaseClient = {
      from: jest.fn().mockReturnThis(),
      select: jest.fn().mockReturnThis(),
      limit: jest.fn().mockResolvedValue({ data: [], error: null }),
    };

    mockSupabaseService = {
      getClient: jest.fn().mockReturnValue(mockSupabaseClient),
      query: jest.fn(),
    };

    mockOpenWAService = {
      healthCheck: jest.fn(),
    };

    mockConfigService = {
      get: jest.fn().mockReturnValue('test-url'),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        HealthService,
        {
          provide: ConfigService,
          useValue: mockConfigService,
        },
        {
          provide: SupabaseService,
          useValue: mockSupabaseService,
        },
        {
          provide: OpenWAService,
          useValue: mockOpenWAService,
        },
      ],
    }).compile();

    service = module.get<HealthService>(HealthService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('getLiveness', () => {
    it('should return alive true', async () => {
      const result = await service.getLiveness();
      expect(result).toEqual({ alive: true });
    });
  });

  describe('getReadiness', () => {
    it('should return ready true when database is up', async () => {
      mockOpenWAService.healthCheck.mockResolvedValue({
        status: 'ok',
        timestamp: new Date().toISOString(),
      });

      const result = await service.getReadiness();

      expect(result).toEqual({ ready: true });
    });

    it('should return ready false when database is down', async () => {
      mockSupabaseService.getClient.mockReturnValue(null);

      const result = await service.getReadiness();

      expect(result).toEqual({ ready: false });
    });
  });

  describe('getHealth', () => {
    it('should return healthy status when all services are up', async () => {
      mockOpenWAService.healthCheck.mockResolvedValue({
        status: 'ok',
        timestamp: new Date().toISOString(),
      });

      const result = await service.getHealth();

      expect(result.status).toBe('healthy');
      expect(result.services.database.status).toBe('up');
      expect(result.services.openwa.status).toBe('up');
      expect(result.version).toBe('1.0.0');
      expect(result.timestamp).toBeDefined();
      expect(result.uptime).toBeGreaterThanOrEqual(0);
    });

    it('should return unhealthy status when all services are down', async () => {
      mockSupabaseService.getClient.mockReturnValue(null);
      mockOpenWAService.healthCheck.mockRejectedValue(new Error('OpenWA Error'));

      const result = await service.getHealth();

      expect(result.status).toBe('unhealthy');
      expect(result.services.database.status).toBe('down');
      expect(result.services.openwa.status).toBe('down');
    });

    it('should return degraded status when some services are down', async () => {
      mockOpenWAService.healthCheck.mockRejectedValue(new Error('OpenWA Error'));

      const result = await service.getHealth();

      expect(result.status).toBe('degraded');
      expect(result.services.database.status).toBe('up');
      expect(result.services.openwa.status).toBe('down');
    });

    it('should include latency for healthy services', async () => {
      mockOpenWAService.healthCheck.mockResolvedValue({
        status: 'ok',
        timestamp: new Date().toISOString(),
      });

      const result = await service.getHealth();

      expect(result.services.database.latency).toBeGreaterThanOrEqual(0);
      expect(result.services.openwa.latency).toBeGreaterThanOrEqual(0);
    });
  });
});
